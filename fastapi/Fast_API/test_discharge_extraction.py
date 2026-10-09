"""Source-grounded regression tests for the fictional discharge PDF."""
import unittest
from pathlib import Path

from pypdf import PdfReader

from main import (
    _clean_discharge_chat_answer,
    _discharge_chat_system_prompt,
    _normalize_discharge_extraction,
)


PDF = Path(__file__).with_name("test_fixtures") / "fictional_discharge_summary.pdf"


class DischargeExtractionRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = "\n".join(page.extract_text() or "" for page in PdfReader(PDF).pages)

    def test_demo_diagnosis_followup_and_prescription_fidelity(self):
        data = {
            "diagnosis": "Seasonal Allergic Rhinitis (J30.2)",
            "condition_explanation": "Seasonal Allergic Rhinitis",
            "summary": (
                "The patient was discharged in stable condition. Attend your "
                "follow-up appointment on 17 October 2026."
            ),
            "follow_up": [{
                "date": "17 October 2026", "time": "10:30 AM",
                "instructions": "Contact the treating clinic.",
            }],
            "medicines": [
                {"name": "Cetirizine 10 mg Tablet", "dose": "1 tablet (10 mg)",
                 "route": "Oral", "frequency": "Once daily", "duration": "5 days",
                 "timing": "9:00 PM", "start_date": "10 October 2026",
                 "end_date": "14 October 2026",
                 "instructions": "May cause drowsiness. Avoid driving if sleepy.",
                 "missing_details": []},
                {"name": "Sodium Chloride 0.65% Nasal Spray",
                 "dose": "2 sprays into each nostril", "route": "Intranasal",
                 "frequency": "Twice daily", "duration": "7 days",
                 "timing": "8:00 AM and 8:00 PM", "start_date": "10 October 2026",
                 "end_date": "16 October 2026",
                 "instructions": "Use gently and follow the spray instructions.",
                 "missing_details": []},
            ],
            "unclear_details": ["Drug allergy history: Not documented."],
        }
        result = _normalize_discharge_extraction(data, self.source)

        self.assertIn("sneezing", result["condition_explanation"].lower())
        self.assertIn("runny nose", result["condition_explanation"].lower())
        self.assertNotEqual(result["condition_explanation"], result["diagnosis"])
        self.assertNotIn("Attend your follow-up appointment", result["summary"])
        self.assertIn("not booked", result["summary"].lower())
        self.assertIn("NOT BOOKED", result["follow_up"][0]["instructions"])
        self.assertEqual(result["medicines"][0]["dose"], "1 tablet (10 mg)")
        self.assertEqual(result["medicines"][0]["instructions"],
                         "May cause drowsiness. Avoid driving if sleepy.")
        self.assertEqual(result["medicines"][1]["dose"],
                         "2 sprays into each nostril")
        self.assertEqual(result["medicines"][1]["route"], "Intranasal")
        self.assertEqual(result["medicines"][1]["instructions"],
                         "Use gently and follow the spray instructions.")
        self.assertEqual(result["medicines"][0]["missing_details"], [])
        self.assertIn("Not documented", result["unclear_details"][0])

    def test_prepare_and_drink_sets_oral_route_only_when_route_missing(self):
        source = (
            "1. Oral rehydration solution\n"
            "Directions: Dissolve one sachet in water; prepare and drink as directed."
        )
        data = {"medicines": [{"name": "Oral rehydration solution", "route": None}]}
        _normalize_discharge_extraction(data, source)
        self.assertEqual(data["medicines"][0]["route"], "Oral")

    def test_unstated_medicine_fields_remain_missing(self):
        source = "1. Example tablet\nSpecial instruction: Take as directed."
        data = {"medicines": [{"name": "Example tablet", "dose": None,
                               "start_date": None, "instructions": None,
                               "missing_details": ["dose", "dates", "instructions"]}]}
        _normalize_discharge_extraction(data, source)
        self.assertIsNone(data["medicines"][0]["dose"])
        self.assertIsNone(data["medicines"][0]["start_date"])
        self.assertIsNone(data["medicines"][0]["instructions"])
        self.assertEqual(len(data["medicines"][0]["missing_details"]), 3)

    def test_chat_prompt_enforces_simple_grounded_safety_and_language(self):
        english = _discharge_chat_system_prompt("English")
        kannada = _discharge_chat_system_prompt("Kannada")
        for phrase in (
            "authenticated patient's selected", "2–5 short sentences",
            "Preserve medicine names, doses, units, route, frequency, duration",
            "Never invent a start date", "Your report does not mention this.",
            "explicitly confirms booking", "no Markdown", "source footers",
        ):
            self.assertIn(phrase, english)
        self.assertIn("natural, easy-to-understand Kannada", kannada)
        self.assertIn("exactly as written", kannada)

    def test_answer_cleanup_removes_markdown_and_duplicate_source_footer(self):
        answer = _clean_discharge_chat_answer(
            "**Take 1 tablet** by mouth as needed.\n\nSource: fictional.pdf"
        )
        self.assertEqual(answer, "Take 1 tablet by mouth as needed.")
        self.assertNotIn("*", answer)
        self.assertNotIn("Source:", answer)


if __name__ == "__main__":
    unittest.main()
