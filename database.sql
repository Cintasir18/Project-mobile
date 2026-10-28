CREATE TABLE IF NOT EXISTS users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    email         VARCHAR(255)            NULL DEFAULT NULL,
    student_id    VARCHAR(50)             NULL UNIQUE,
    password_hash VARCHAR(255)            NOT NULL,
    nama          VARCHAR(100)            NOT NULL,
    role          ENUM('student','admin') NOT NULL DEFAULT 'student',
    institution   VARCHAR(150)            NULL,
    is_active     TINYINT(1)              NOT NULL DEFAULT 1,
    created_at    TIMESTAMP               DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- API TOKENS (sesi login)
-- =====================================================
CREATE TABLE IF NOT EXISTS api_tokens (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT          NOT NULL,
    token_hash VARCHAR(64)  NOT NULL UNIQUE,
    expires_at DATETIME     NOT NULL,
    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =====================================================
-- INSTITUTIONS
-- =====================================================
CREATE TABLE IF NOT EXISTS institutions (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(200)  NOT NULL,
    type       VARCHAR(100)  NOT NULL,
    location   VARCHAR(255)  NOT NULL,
    latitude   DECIMAL(10,7) NOT NULL,
    longitude  DECIMAL(10,7) NOT NULL,
    is_active  TINYINT(1)    NOT NULL DEFAULT 1,
    created_at TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- =====================================================
-- BILLS (tagihan pembayaran)
-- =====================================================
CREATE TABLE IF NOT EXISTS bills (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT                          NOT NULL,
    bill_type     VARCHAR(100)                 NOT NULL DEFAULT 'SPP',
    billing_month TINYINT UNSIGNED             NOT NULL,  -- 1–12
    billing_year  SMALLINT UNSIGNED            NOT NULL,
    amount        DECIMAL(15,2)                NOT NULL,
    paid_amount   DECIMAL(15,2)                NOT NULL DEFAULT 0,
    due_date      DATE                         NOT NULL,
    paid_at       DATETIME                     NULL,
    status        ENUM('unpaid','partial','paid') NOT NULL DEFAULT 'unpaid',
    notes         TEXT                         NULL,
    created_at    TIMESTAMP                    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uq_user_bill_period (user_id, bill_type, billing_month, billing_year)
);

-- =====================================================
-- PAYMENT_BILLS (alias / tabel alternatif untuk payment page)
-- =====================================================
CREATE TABLE IF NOT EXISTS payment_bills (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT                      NOT NULL,
    period     VARCHAR(7)               NOT NULL,   -- format: YYYY-MM
    amount     DECIMAL(15,2)            NOT NULL,
    status     ENUM('unpaid','paid')    NOT NULL DEFAULT 'unpaid',
    due_date   DATE                     NOT NULL,
    paid_at    DATETIME                 NULL,
    created_at TIMESTAMP                DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uq_user_period (user_id, period)
);
