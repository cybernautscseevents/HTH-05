CREATE TABLE IF NOT EXISTS patient_discharge_reports (
    report_id BIGINT NOT NULL AUTO_INCREMENT,
    patient_id INT NOT NULL,
    hospital_name VARCHAR(255) NULL,
    doctor_name VARCHAR(255) NULL,
    uploaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    original_filename VARCHAR(255) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    document_reference CHAR(64) NOT NULL,
    extracted_text MEDIUMTEXT NOT NULL,
    structured_data JSON NOT NULL,
    summary TEXT NOT NULL,
    PRIMARY KEY (report_id),
    UNIQUE KEY uq_patient_discharge_document (patient_id, document_reference),
    KEY ix_patient_discharge_reports_patient_id (patient_id),
    CONSTRAINT fk_discharge_report_patient
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
