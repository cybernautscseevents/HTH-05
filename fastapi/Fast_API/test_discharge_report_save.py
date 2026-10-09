"""Fictional report integration tests. All writes use an isolated database.

Set SAATHI_REPORT_TEST_DATABASE_URL_FILE to a protected file containing the
isolated MySQL URL. Never point it to a shared database. SAATHI_LIVE_GROQ=1
enables one real Groq upload/save/retrieve/English/Kannada chat round trip.
"""
import json
import os
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

import main
from auth import get_current_user
from models import Patient, PatientDischargeReport
from schemas import PatientDischargeReportSave

PDF = Path(__file__).with_name('test_fixtures') / 'fictional_discharge_summary.pdf'
PLAN = {
    'diagnosis': 'Seasonal Allergic Rhinitis (J30.2)',
    'condition_explanation': 'Your report describes sneezing and a runny nose.',
    'hospital': 'Sample General Hospital', 'doctor': 'Dr. Mira Rao (Fictional)',
    'summary': 'You were stable at discharge. Follow the written medicine schedule. Your recommended review is not booked.',
    'medicines': [{'name': 'Cetirizine 10 mg Tablet', 'dose': '1 tablet (10 mg)',
                  'route': 'Oral', 'frequency': 'Once daily', 'duration': '5 days',
                  'timing': '9:00 PM', 'start_date': '10 October 2026',
                  'end_date': '14 October 2026',
                  'instructions': 'May cause drowsiness. Avoid driving if sleepy.'}],
    'follow_up': [{'date': '17 October 2026', 'time': '10:30 AM',
                   'instructions': 'NOT BOOKED. Contact the treating clinic.'}],
    'unclear_details': ['Drug allergy history: Not documented.'],
}


class DischargeReportSaveTests(unittest.TestCase):
    def setUp(self):
        url_file = os.getenv('SAATHI_REPORT_TEST_DATABASE_URL_FILE')
        if url_file:
            url = Path(url_file).read_text().strip()
            from sqlalchemy.engine import make_url
            parsed = make_url(url)
            if parsed.host != '127.0.0.1' or parsed.database != 'saathi_report_test':
                raise RuntimeError('Refusing integration writes outside the isolated local test database')
            self.engine = create_engine(url, hide_parameters=True)
            mode_file = Path(url_file).with_name('test-sql-mode.txt')
            if mode_file.exists():
                from sqlalchemy import event
                mode = mode_file.read_text().strip()
                @event.listens_for(self.engine, 'connect')
                def match_source_sql_mode(connection, _):
                    with connection.cursor() as cursor:
                        cursor.execute('SET SESSION sql_mode = %s', (mode,))
        else:
            self.engine = create_engine('sqlite://', connect_args={'check_same_thread': False}, poolclass=StaticPool)
            # Only these tables, on this explicitly local in-memory engine.
            Patient.__table__.create(self.engine)
            PatientDischargeReport.__table__.create(self.engine)
        with Session(self.engine) as db:
            db.add_all([Patient(patient_id=990001, registration_no='DEMO-SAVE-1', name='Fictional Aarav', registration_date=datetime(2026, 10, 9)),
                        Patient(patient_id=990002, registration_no='DEMO-SAVE-2', name='Fictional Other', registration_date=datetime(2026, 10, 9))])
            db.commit()
        self.user = {'role': 'patient', 'patient_id': 990001, 'user_id': None}

        def isolated_db():
            with Session(self.engine) as db:
                yield db

        main.app.dependency_overrides[main.get_db] = isolated_db
        main.app.dependency_overrides[get_current_user] = lambda: self.user
        self.client = TestClient(main.app)

    def tearDown(self):
        self.client.close()
        main.app.dependency_overrides.clear()
        with Session(self.engine) as db:
            db.query(PatientDischargeReport).delete()
            db.query(Patient).filter(Patient.patient_id.in_([990001, 990002])).delete()
            db.commit()
        self.engine.dispose()

    @staticmethod
    def payload():
        return {'original_filename': PDF.name, 'content_type': 'application/pdf',
                'document_reference': 'a' * 64, 'extracted_text': 'Synthetic discharge source text for fictional test patient only.',
                'structured_data': PLAN, 'summary': PLAN['summary']}

    def test_save_retrieve_deduplicate_and_patient_ownership(self):
        saved = self.client.post('/patients/me/discharge-reports', json=self.payload())
        self.assertEqual(saved.status_code, 201, saved.text)
        report = saved.json()
        self.assertEqual(report['patient_id'], 990001)
        retry = self.client.post('/patients/me/discharge-reports', json=self.payload())
        self.assertEqual(retry.json()['report_id'], report['report_id'])
        with Session(self.engine) as reopened:
            self.assertEqual(reopened.query(PatientDischargeReport).count(), 1)
            self.assertEqual(reopened.get(PatientDischargeReport, report['report_id']).structured_data, PLAN)
        self.assertEqual(len(self.client.get('/patients/me/discharge-reports').json()), 1)
        self.user = {'role': 'patient', 'patient_id': 990002}
        self.assertEqual(self.client.get('/patients/me/discharge-reports').json(), [])
        denied = self.client.post('/patients/me/discharge-chat', json={
            'report_id': report['report_id'], 'question': 'What is my dose?', 'language': 'English'})
        self.assertEqual(denied.status_code, 404)

    def test_unlinked_and_staff_sessions_cannot_save(self):
        self.user = {'role': 'patient', 'patient_id': None}
        self.assertEqual(self.client.post('/patients/me/discharge-reports', json=self.payload()).status_code, 401)
        self.user = {'role': 'doctor', 'patient_id': 990001}
        self.assertEqual(self.client.post('/patients/me/discharge-reports', json=self.payload()).status_code, 403)

    def test_concurrent_mysql_saves_return_one_persisted_report(self):
        if self.engine.dialect.name != 'mysql':
            self.skipTest('Concurrent independent connections require isolated MySQL')
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(max_workers=4) as workers:
            responses = list(workers.map(lambda _: self.client.post('/patients/me/discharge-reports', json=self.payload()), range(4)))
        self.assertTrue(all(response.status_code == 201 for response in responses))
        self.assertEqual(len({response.json()['report_id'] for response in responses}), 1)
        with Session(self.engine) as reopened:
            self.assertEqual(reopened.query(PatientDischargeReport).count(), 1)

    def test_commit_failure_rolls_back_and_does_not_confirm_save(self):
        with Session(self.engine) as db:
            with patch.object(db, 'commit', side_effect=OperationalError('insert', {}, Exception('synthetic failure'))):
                with self.assertRaises(HTTPException) as caught:
                    main.save_discharge_report(PatientDischargeReportSave(**self.payload()), db, self.user)
            self.assertEqual(caught.exception.status_code, 503)
        with Session(self.engine) as reopened:
            self.assertEqual(reopened.query(PatientDischargeReport).count(), 0)

    def test_missing_storage_is_clear_without_creating_table(self):
        empty = create_engine('sqlite://')
        with Session(empty) as db:
            with self.assertRaises(HTTPException) as caught:
                main.require_discharge_report_storage(db)
            self.assertEqual(caught.exception.status_code, 503)
            self.assertIn('patient_discharge_reports', caught.exception.detail)
        from sqlalchemy import inspect
        self.assertFalse(inspect(empty).has_table('patient_discharge_reports'))
        empty.dispose()

    def exercise_pdf_round_trip(self, live=False):
        completion = AsyncMock()
        completion.side_effect = [
            SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps(PLAN)))]),
            SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='Your report says 1 tablet (10 mg) once daily at 9:00 PM.'))]),
            SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content='ನಿಮ್ಮ ವರದಿಯಲ್ಲಿ 1 tablet (10 mg) ಎಂದು ಹೇಳಿದೆ.'))]),
        ]
        from contextlib import ExitStack
        with ExitStack() as stack:
            if not live:
                fake = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=completion)))
                stack.enter_context(patch('groq.AsyncGroq', return_value=fake))
                stack.enter_context(patch.dict(os.environ, {'GROQ_API_KEY': 'fictional-test-key'}))
            response = self.client.post('/patients/me/discharge-summary', files={'file': (PDF.name, PDF.read_bytes(), 'application/pdf')})
            self.assertEqual(response.status_code, 200, response.text)
            extracted = response.json()
            self.assertIn('Seasonal', extracted['extracted']['diagnosis'])
            self.assertIn('Not documented', ' '.join(extracted['extracted']['unclear_details']))
            medicines = extracted['extracted']['medicines']
            cetirizine = next(item for item in medicines if 'Cetirizine' in item['name'])
            # The existing extractor can represent strength separately from
            # the tablet count. Check both documented values, then require
            # byte-for-byte structured-data preservation through persistence.
            self.assertIn('1 tablet', cetirizine['dose'])
            self.assertIn('10 mg', ' '.join(str(cetirizine.get(field) or '') for field in ['name', 'dose', 'strength']))
            self.assertEqual(cetirizine['instructions'], 'May cause drowsiness. Avoid driving if sleepy.')
            self.assertEqual(cetirizine['timing'], '9:00 PM')
            body = {**self.payload(), 'document_reference': extracted['source']['document_reference'],
                    'extracted_text': extracted['extracted_text'], 'structured_data': extracted['extracted'],
                    'summary': extracted['summary']}
            saved = self.client.post('/patients/me/discharge-reports', json=body)
            self.assertEqual(saved.status_code, 201, saved.text)
            report_id = saved.json()['report_id']
            retrieved = self.client.get('/patients/me/discharge-reports')
            self.assertEqual(retrieved.json()[0]['structured_data'], extracted['extracted'])
            for language in ['English', 'Kannada']:
                answer = self.client.post('/patients/me/discharge-chat', json={
                    'report_id': report_id, 'question': 'What dose and time does my report give for Cetirizine?', 'language': language})
                self.assertEqual(answer.status_code, 200, answer.text)
                self.assertEqual(answer.json()['source']['report_id'], report_id)
                self.assertIn('10 mg', answer.json()['answer'])
            if not live:
                self.assertEqual(completion.await_count, 3)
                grounded_message = completion.call_args_list[1].kwargs['messages'][1]['content']
                grounded_context = json.loads(grounded_message.split('\n', 1)[1].rsplit('\n\nPatient question:', 1)[0])
                self.assertEqual(grounded_context['document_text'], extracted['extracted_text'])

    def test_pdf_upload_extract_save_retrieve_chat_mocked_groq(self):
        self.exercise_pdf_round_trip()

    @unittest.skipUnless(os.getenv('SAATHI_LIVE_GROQ') == '1', 'Real Groq requires explicit live-test setting')
    def test_pdf_upload_extract_save_retrieve_chat_live_groq(self):
        self.exercise_pdf_round_trip(live=True)


if __name__ == '__main__':
    unittest.main()
