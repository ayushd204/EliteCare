
/* =====================================================================
   elitecare Health Network — Internal Hospital System Tables
   Target: Neon Postgres (source system, schema: public)
   Creates hospitals, doctors, patients + seed sample data.
   ===================================================================== */

DROP TABLE IF EXISTS patients;
DROP TABLE IF EXISTS doctors;
DROP TABLE IF EXISTS hospitals;

/* ---------------------------------------------------------------------
   1. hospitals — hospital/facility master data (FULL load)
   --------------------------------------------------------------------- */
CREATE TABLE hospitals (
    hospital_id     SERIAL PRIMARY KEY,
    hospital_name   VARCHAR(150) NOT NULL,
    city            VARCHAR(100),
    state           VARCHAR(50),
    hospital_type   VARCHAR(50),
    bed_count       INT,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

/* ---------------------------------------------------------------------
   2. doctors — doctor/physician roster (FULL load)
   --------------------------------------------------------------------- */
CREATE TABLE doctors (
    doctor_id       SERIAL PRIMARY KEY,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    specialty       VARCHAR(100),
    hospital_id     INT REFERENCES hospitals (hospital_id),
    phone_number    VARCHAR(20),
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

/* ---------------------------------------------------------------------
   3. patients — patient registration & demographics (MERGE load)
      watermark_column = updated_at, merge_keys = patient_id
   --------------------------------------------------------------------- */
CREATE TABLE patients (
    patient_id              SERIAL PRIMARY KEY,
    first_name              VARCHAR(100) NOT NULL,
    last_name               VARCHAR(100) NOT NULL,
    date_of_birth            DATE,
    gender                   VARCHAR(10),
    city                     VARCHAR(100),
    state                    VARCHAR(50),
    registered_hospital_id   INT REFERENCES hospitals (hospital_id),
    insurance_provider_id    INT,
    created_at               TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMP NOT NULL DEFAULT NOW()
);

/* =====================================================================
   Seed data — set-based generation
   Target volumes: ~50 hospitals, ~10 doctors/hospital (~500),
   ~100 patients/hospital (~5000).
   ===================================================================== */

-- 1. hospitals: 50 rows, cycling through 25 city/state pairs

WITH generated AS (
    SELECT
        gs,
        (ARRAY[
            'New York','Brooklyn','Queens','Albany','Buffalo',
            'Los Angeles','San Jose','San Francisco','Fresno','Oakland',
            'Austin','Dallas','Houston','San Antonio','El Paso',
            'Seattle','Tacoma','Spokane','Portland','Salem',
            'Denver','Colorado Springs','Boulder','Phoenix','Tucson'
        ])[1 + (gs % 25)] AS city,

        (ARRAY[
            'NY','NY','NY','NY','NY',
            'CA','CA','CA','CA','CA',
            'TX','TX','TX','TX','TX',
            'WA','WA','WA','OR','OR',
            'CO','CO','CO','AZ','AZ'
        ])[1 + (gs % 25)] AS state,

        (ARRAY[
            'General','Specialty','Teaching','Community','Regional'
        ])[1 + (gs % 5)] AS hospital_type,

        (ARRAY[
            'University Hospital','Memorial Medical Center',
            'Valley Health Institute','Metropolitan Hospital',
            'Pioneer Medical Center','Northside Hospital',
            'Riverside Health Center'
        ])[1 + (gs % 7)] AS name_suffix

    FROM generate_series(0, 49) AS gs
)
INSERT INTO hospitals (
    hospital_name, city, state, hospital_type, bed_count
)
SELECT
    city || ' ' || name_suffix,
    city,
    state,
    hospital_type,
    100 + floor(random() * 350)::int
FROM generated;


-- 2. doctors: ~10 per hospital (~500 rows)

INSERT INTO doctors (
    first_name, last_name, specialty, hospital_id, phone_number
)
SELECT
    (ARRAY[
        'Daniel','Emily','Matthew','Olivia','Christopher',
        'Sophia','Andrew','Isabella','Joshua','Mia',
        'Ethan','Charlotte','Alexander','Amelia','Benjamin',
        'Harper','Samuel','Evelyn','Henry','Abigail'
    ])[1 + ((h.hospital_id * 7 + n * 3) % 20)],

    (ARRAY[
        'Thompson','White','Harris','Clark','Lewis',
        'Robinson','Walker','Hall','Allen','Young',
        'King','Wright','Scott','Green','Baker',
        'Adams','Nelson','Hill','Campbell','Mitchell'
    ])[1 + ((h.hospital_id * 11 + n * 5) % 20)],

    (ARRAY[
        'Cardiology','Pediatrics','Orthopedics','Neurology',
        'Oncology','General Medicine','Endocrinology',
        'Dermatology','Psychiatry','Radiology',
        'Emergency Medicine','Gastroenterology'
    ])[1 + ((h.hospital_id * 2 + n * 3) % 12)],

    h.hospital_id,

    '555-' || lpad(
        ((h.hospital_id - 1) * 10 + n + 5000)::text,
        4,
        '0'
    )

FROM hospitals h
CROSS JOIN generate_series(1, 10) AS n;


-- 3. patients: ~100 per hospital (~5000 rows)
--    City/state inherited from registering hospital.
--    Insurance provider IDs distributed across 25 providers.

INSERT INTO patients (
    first_name,
    last_name,
    date_of_birth,
    gender,
    city,
    state,
    registered_hospital_id,
    insurance_provider_id
)
SELECT
    (ARRAY[
        'Ava','Noah','Liam','Emma','Lucas',
        'Grace','Mason','Chloe','Logan','Ella',
        'Jacob','Aria','Owen','Lily','Elijah',
        'Nora','Aiden','Zoe','Carter','Hannah'
    ])[1 + ((h.hospital_id * 13 + n * 3) % 20)],

    (ARRAY[
        'Parker','Evans','Edwards','Collins','Stewart',
        'Morris','Rogers','Reed','Cook','Morgan',
        'Bell','Murphy','Bailey','Rivera','Cooper',
        'Richardson','Cox','Howard','Ward','Torres'
    ])[1 + ((h.hospital_id * 17 + n * 9) % 20)],

    DATE '1940-01-01' + floor(random() * 31000)::int,

    CASE
        WHEN (h.hospital_id * 3 + n) % 2 = 0
        THEN 'M'
        ELSE 'F'
    END,

    h.city,
    h.state,
    h.hospital_id,

    1 + ((h.hospital_id * 7 + n * 3) % 25)

FROM hospitals h
CROSS JOIN generate_series(1, 100) AS n;
