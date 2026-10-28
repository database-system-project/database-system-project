CREATE SCHEMA IF NOT EXISTS hospital DEFAULT CHARACTER SET utf8mb4;
USE hospital;

CREATE TABLE user_account (
  account_id          BIGINT       NOT NULL AUTO_INCREMENT COMMENT '계정번호',
  login_id            VARCHAR(50)  NOT NULL COMMENT '아이디',
  password_hash       VARCHAR(255) NOT NULL COMMENT '비밀번호',
  role                VARCHAR(20)  NOT NULL COMMENT '역할: PATIENT/DOCTOR/RECEPTION/BILLING/ADMIN',
  account_status      VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE' COMMENT '계정상태: ACTIVE/INACTIVE',
  account_created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '계정 생성일시',
  PRIMARY KEY (account_id),
  UNIQUE KEY uq_account_login_id (login_id),
  CONSTRAINT ck_account_role CHECK (role IN ('PATIENT','DOCTOR','RECEPTION','BILLING','ADMIN')),
  CONSTRAINT ck_account_status CHECK (account_status IN ('ACTIVE','INACTIVE'))
) ENGINE=InnoDB COMMENT='사용자계정';

CREATE TABLE patient (
  patient_id         BIGINT      NOT NULL AUTO_INCREMENT COMMENT '환자번호',
  account_id         BIGINT      NOT NULL COMMENT '계정번호',
  patient_name       VARCHAR(50) NOT NULL COMMENT '환자명',
  birth_date         DATE        NOT NULL COMMENT '생년월일',
  gender             VARCHAR(1)  NOT NULL COMMENT '성별: M/F',
  phone              VARCHAR(20) NOT NULL COMMENT '전화번호',
  privacy_agreed_at  DATETIME    NOT NULL COMMENT '개인정보 동의일시',
  PRIMARY KEY (patient_id),
  UNIQUE KEY uq_patient_account (account_id),
  UNIQUE KEY uq_patient_identity (patient_name, birth_date, phone),
  CONSTRAINT fk_patient_account FOREIGN KEY (account_id) REFERENCES user_account (account_id),
  CONSTRAINT ck_patient_gender CHECK (gender IN ('M','F'))
) ENGINE=InnoDB AUTO_INCREMENT=100001 COMMENT='환자';

CREATE TABLE department (
  department_id      BIGINT      NOT NULL AUTO_INCREMENT COMMENT '진료과번호',
  department_name    VARCHAR(50) NOT NULL COMMENT '진료과명',
  department_active  TINYINT(1)  NOT NULL DEFAULT 1 COMMENT '진료과 사용여부',
  PRIMARY KEY (department_id),
  UNIQUE KEY uq_department_name (department_name)
) ENGINE=InnoDB COMMENT='진료과';

CREATE TABLE doctor (
  doctor_id      BIGINT      NOT NULL AUTO_INCREMENT COMMENT '의사번호',
  account_id     BIGINT      NOT NULL COMMENT '계정번호',
  department_id  BIGINT      NOT NULL COMMENT '진료과번호',
  doctor_name    VARCHAR(50) NOT NULL COMMENT '의사명',
  doctor_active  TINYINT(1)  NOT NULL DEFAULT 1 COMMENT '의사 사용여부',
  PRIMARY KEY (doctor_id),
  UNIQUE KEY uq_doctor_account (account_id),
  CONSTRAINT fk_doctor_account FOREIGN KEY (account_id) REFERENCES user_account (account_id),
  CONSTRAINT fk_doctor_department FOREIGN KEY (department_id) REFERENCES department (department_id)
) ENGINE=InnoDB COMMENT='의사';

CREATE TABLE staff (
  staff_id      BIGINT      NOT NULL AUTO_INCREMENT COMMENT '직원번호',
  account_id    BIGINT      NOT NULL COMMENT '계정번호',
  staff_name    VARCHAR(50) NOT NULL COMMENT '직원명',
  staff_active  TINYINT(1)  NOT NULL DEFAULT 1 COMMENT '직원 사용여부',
  PRIMARY KEY (staff_id),
  UNIQUE KEY uq_staff_account (account_id),
  CONSTRAINT fk_staff_account FOREIGN KEY (account_id) REFERENCES user_account (account_id)
) ENGINE=InnoDB COMMENT='병원직원';

CREATE TABLE doctor_schedule (
  schedule_id      BIGINT     NOT NULL AUTO_INCREMENT COMMENT '일정번호',
  doctor_id        BIGINT     NOT NULL COMMENT '의사번호',
  schedule_date    DATE       NOT NULL COMMENT '진료일',
  reception_start  TIME       NULL COMMENT '접수 시작시간',
  closing_time     TIME       NULL COMMENT '진료 마감시간',
  lunch_start      TIME       NULL COMMENT '점심 시작시간',
  lunch_end        TIME       NULL COMMENT '점심 종료시간',
  is_closed        TINYINT(1) NOT NULL DEFAULT 0 COMMENT '휴진여부',
  PRIMARY KEY (schedule_id),
  UNIQUE KEY uq_schedule_doctor_date (doctor_id, schedule_date),
  CONSTRAINT fk_schedule_doctor FOREIGN KEY (doctor_id) REFERENCES doctor (doctor_id),
  CONSTRAINT ck_schedule_time CHECK (is_closed = 1 OR reception_start < closing_time)
) ENGINE=InnoDB COMMENT='의사일정';

CREATE TABLE reservation (
  reservation_id            BIGINT      NOT NULL AUTO_INCREMENT COMMENT '예약번호',
  patient_id                BIGINT      NOT NULL COMMENT '환자번호',
  schedule_id               BIGINT      NOT NULL COMMENT '일정번호',
  planned_reception_at      DATETIME    NOT NULL COMMENT '접수 예정일시',
  reservation_status        VARCHAR(20) NOT NULL DEFAULT 'RESERVED' COMMENT '예약상태: RESERVED/CHECKED_IN/CANCELLED',
  reserved_at               DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '예약 신청일시',
  reservation_cancelled_at  DATETIME    NULL COMMENT '예약 취소일시',
  PRIMARY KEY (reservation_id),
  KEY idx_reservation_slot (schedule_id, planned_reception_at),
  CONSTRAINT fk_reservation_patient FOREIGN KEY (patient_id) REFERENCES patient (patient_id),
  CONSTRAINT fk_reservation_schedule FOREIGN KEY (schedule_id) REFERENCES doctor_schedule (schedule_id),
  CONSTRAINT ck_reservation_status CHECK (reservation_status IN ('RESERVED','CHECKED_IN','CANCELLED')),
  CONSTRAINT ck_reservation_30min CHECK (MINUTE(planned_reception_at) IN (0, 30) AND SECOND(planned_reception_at) = 0)
) ENGINE=InnoDB COMMENT='예약';

CREATE TABLE visit (
  visit_id                BIGINT      NOT NULL AUTO_INCREMENT COMMENT '접수번호',
  reservation_id          BIGINT      NOT NULL COMMENT '예약번호',
  checked_in_at           DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '접수일시',
  checked_in_by_staff_id  BIGINT      NOT NULL COMMENT '접수 처리 직원번호',
  visit_status            VARCHAR(20) NOT NULL DEFAULT 'WAITING' COMMENT '진료상태: WAITING/IN_PROGRESS/COMPLETED/CANCELLED',
  started_at              DATETIME    NULL COMMENT '진료 시작일시',
  completed_at            DATETIME    NULL COMMENT '진료 완료일시',
  visit_cancelled_at      DATETIME    NULL COMMENT '접수 취소일시',
  cancelled_by_staff_id   BIGINT      NULL COMMENT '접수 취소 직원번호',
  PRIMARY KEY (visit_id),
  UNIQUE KEY uq_visit_reservation (reservation_id),
  CONSTRAINT fk_visit_reservation FOREIGN KEY (reservation_id) REFERENCES reservation (reservation_id),
  CONSTRAINT fk_visit_checkin_staff FOREIGN KEY (checked_in_by_staff_id) REFERENCES staff (staff_id),
  CONSTRAINT fk_visit_cancel_staff FOREIGN KEY (cancelled_by_staff_id) REFERENCES staff (staff_id),
  CONSTRAINT ck_visit_status CHECK (visit_status IN ('WAITING','IN_PROGRESS','COMPLETED','CANCELLED'))
) ENGINE=InnoDB COMMENT='접수';

CREATE TABLE medical_record (
  record_id          BIGINT   NOT NULL AUTO_INCREMENT COMMENT '진료기록번호',
  visit_id           BIGINT   NOT NULL COMMENT '접수번호',
  symptoms           TEXT     NULL COMMENT '증상',
  diagnosis          TEXT     NULL COMMENT '진단',
  treatment_note     TEXT     NULL COMMENT '진료내용',
  written_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '작성일시',
  record_updated_at  DATETIME NULL COMMENT '수정일시',
  PRIMARY KEY (record_id),
  UNIQUE KEY uq_record_visit (visit_id),
  CONSTRAINT fk_record_visit FOREIGN KEY (visit_id) REFERENCES visit (visit_id)
) ENGINE=InnoDB COMMENT='진료기록';

CREATE TABLE medicine (
  medicine_id      BIGINT       NOT NULL AUTO_INCREMENT COMMENT '약품번호',
  item_seq         VARCHAR(20)  NOT NULL COMMENT '품목기준코드',
  product_name     VARCHAR(200) NOT NULL COMMENT '제품명',
  company_name     VARCHAR(100) NULL COMMENT '업체명',
  efficacy         TEXT         NULL COMMENT '효능',
  usage_text       TEXT         NULL COMMENT '사용법',
  precautions      TEXT         NULL COMMENT '주의사항',
  storage          TEXT         NULL COMMENT '보관법',
  medicine_active  TINYINT(1)   NOT NULL DEFAULT 1 COMMENT '약품 사용여부',
  PRIMARY KEY (medicine_id),
  UNIQUE KEY uq_medicine_item_seq (item_seq)
) ENGINE=InnoDB COMMENT='약품';

CREATE TABLE drug_interaction (
  medicine_a_id        BIGINT NOT NULL COMMENT '약품번호A',
  medicine_b_id        BIGINT NOT NULL COMMENT '약품번호B',
  interaction_content  TEXT   NOT NULL COMMENT '병용금기 내용',
  PRIMARY KEY (medicine_a_id, medicine_b_id),
  CONSTRAINT fk_interaction_med_a FOREIGN KEY (medicine_a_id) REFERENCES medicine (medicine_id),
  CONSTRAINT fk_interaction_med_b FOREIGN KEY (medicine_b_id) REFERENCES medicine (medicine_id),
  CONSTRAINT ck_interaction_order CHECK (medicine_a_id < medicine_b_id)
) ENGINE=InnoDB COMMENT='병용금기';

CREATE TABLE age_contraindication (
  medicine_id    BIGINT      NOT NULL COMMENT '약품번호',
  age_seq        INT         NOT NULL COMMENT '연령금기 일련번호',
  age_limit      SMALLINT    NOT NULL COMMENT '기준 나이',
  age_condition  VARCHAR(10) NOT NULL COMMENT '나이 조건: UNDER/OR_UNDER',
  age_content    TEXT        NOT NULL COMMENT '연령금기 내용',
  PRIMARY KEY (medicine_id, age_seq),
  CONSTRAINT fk_age_rule_medicine FOREIGN KEY (medicine_id) REFERENCES medicine (medicine_id),
  CONSTRAINT ck_age_condition CHECK (age_condition IN ('UNDER','OR_UNDER')),
  CONSTRAINT ck_age_limit CHECK (age_limit > 0)
) ENGINE=InnoDB COMMENT='연령금기';

CREATE TABLE prescription (
  prescription_id      BIGINT      NOT NULL AUTO_INCREMENT COMMENT '처방번호',
  visit_id             BIGINT      NOT NULL COMMENT '접수번호',
  prescribed_at        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '처방일시',
  prescription_status  VARCHAR(20) NOT NULL DEFAULT 'ISSUED' COMMENT '처방상태: ISSUED/CANCELLED',
  PRIMARY KEY (prescription_id),
  CONSTRAINT fk_prescription_visit FOREIGN KEY (visit_id) REFERENCES visit (visit_id),
  CONSTRAINT ck_prescription_status CHECK (prescription_status IN ('ISSUED','CANCELLED'))
) ENGINE=InnoDB COMMENT='처방';

CREATE TABLE prescription_item (
  prescription_id  BIGINT       NOT NULL COMMENT '처방번호',
  medicine_id      BIGINT       NOT NULL COMMENT '약품번호',
  dose_amount      DECIMAL(6,2) NOT NULL COMMENT '1회 투약량',
  dose_unit        VARCHAR(10)  NOT NULL COMMENT '투약 단위',
  times_per_day    SMALLINT     NOT NULL COMMENT '하루 투약횟수',
  interval_days    SMALLINT     NOT NULL DEFAULT 1 COMMENT '투여 간격',
  total_days       SMALLINT     NOT NULL COMMENT '총 투약일수',
  timing           VARCHAR(20)  NOT NULL COMMENT '복용 시점: BEFORE_MEAL/AFTER_MEAL/BEDTIME',
  directions       VARCHAR(200) NULL COMMENT '복용 방법',
  PRIMARY KEY (prescription_id, medicine_id),
  CONSTRAINT fk_item_prescription FOREIGN KEY (prescription_id) REFERENCES prescription (prescription_id),
  CONSTRAINT fk_item_medicine FOREIGN KEY (medicine_id) REFERENCES medicine (medicine_id),
  CONSTRAINT ck_item_dose CHECK (dose_amount > 0),
  CONSTRAINT ck_item_times CHECK (times_per_day > 0),
  CONSTRAINT ck_item_interval CHECK (interval_days > 0),
  CONSTRAINT ck_item_days CHECK (total_days > 0),
  CONSTRAINT ck_item_timing CHECK (timing IN ('BEFORE_MEAL','AFTER_MEAL','BEDTIME'))
) ENGINE=InnoDB COMMENT='처방상세';

CREATE TABLE contraindication_override (
  prescription_id      BIGINT      NOT NULL COMMENT '처방번호',
  override_seq         INT         NOT NULL COMMENT '금기확인 일련번호',
  medicine_id          BIGINT      NOT NULL COMMENT '약품번호',
  contra_type          VARCHAR(20) NOT NULL COMMENT '금기 종류: COMBINATION/AGE',
  related_medicine_id  BIGINT      NULL COMMENT '병용금기 상대 약품번호',
  contra_content       TEXT        NOT NULL COMMENT '확인 당시 금기 내용',
  override_reason      TEXT        NOT NULL COMMENT '처방 사유',
  recorded_at          DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '기록일시',
  PRIMARY KEY (prescription_id, override_seq),
  CONSTRAINT fk_override_prescription FOREIGN KEY (prescription_id) REFERENCES prescription (prescription_id),
  CONSTRAINT fk_override_medicine FOREIGN KEY (medicine_id) REFERENCES medicine (medicine_id),
  CONSTRAINT fk_override_related FOREIGN KEY (related_medicine_id) REFERENCES medicine (medicine_id),
  CONSTRAINT ck_override_type CHECK (contra_type IN ('COMBINATION','AGE')),
  CONSTRAINT ck_override_related CHECK (
    (contra_type = 'COMBINATION' AND related_medicine_id IS NOT NULL) OR
    (contra_type = 'AGE' AND related_medicine_id IS NULL))
) ENGINE=InnoDB COMMENT='처방 금기 확인 기록';

CREATE TABLE consultation_fee (
  fee_id           BIGINT   NOT NULL AUTO_INCREMENT COMMENT '진찰료번호',
  fee_amount       INT      NOT NULL COMMENT '진찰료 금액',
  effective_from   DATETIME NOT NULL COMMENT '적용 시작일시',
  set_by_staff_id  BIGINT   NOT NULL COMMENT '등록 관리자 직원번호',
  PRIMARY KEY (fee_id),
  UNIQUE KEY uq_fee_effective (effective_from),
  CONSTRAINT fk_fee_staff FOREIGN KEY (set_by_staff_id) REFERENCES staff (staff_id),
  CONSTRAINT ck_fee_amount CHECK (fee_amount >= 0)
) ENGINE=InnoDB COMMENT='진찰료';

CREATE TABLE payment (
  payment_id             BIGINT   NOT NULL AUTO_INCREMENT COMMENT '결제번호',
  visit_id               BIGINT   NOT NULL COMMENT '접수번호',
  paid_amount            INT      NOT NULL COMMENT '결제금액',
  paid_at                DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '결제일시',
  processed_by_staff_id  BIGINT   NOT NULL COMMENT '수납 처리 직원번호',
  PRIMARY KEY (payment_id),
  UNIQUE KEY uq_payment_visit (visit_id),
  CONSTRAINT fk_payment_visit FOREIGN KEY (visit_id) REFERENCES visit (visit_id),
  CONSTRAINT fk_payment_staff FOREIGN KEY (processed_by_staff_id) REFERENCES staff (staff_id),
  CONSTRAINT ck_payment_amount CHECK (paid_amount >= 0)
) ENGINE=InnoDB COMMENT='결제';
