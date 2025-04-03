DELIMITER $$










DROP FUNCTION IF EXISTS IS_UUID$$

CREATE FUNCTION IF NOT EXISTS IS_UUID (uuid VARCHAR(255)) RETURNS SMALLINT NO SQL DETERMINISTIC
BEGIN
	DECLARE _result SMALLINT;

	DECLARE regexp1 VARCHAR(255);
	DECLARE regexp2 VARCHAR(255);
	DECLARE regexp3 VARCHAR(255);

	SET _result = 0;

	SET regexp1 = '^\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}$';
	SET regexp2 = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
	SET regexp3 = '^[0-9a-fA-F]{8}[0-9a-fA-F]{4}[0-9a-fA-F]{4}[0-9a-fA-F]{4}[0-9a-fA-F]{12}$';

	IF uuid IS NULL THEN
		SET _result = NULL;
	ELSE
		IF uuid REGEXP regexp1 THEN
			SET uuid = REPLACE(REPLACE(uuid, '{', ''), '}', '');
		END IF;
	   
		IF uuid REGEXP regexp2 THEN
			SET uuid = REPLACE(uuid, '-', '');
		END IF;

		IF uuid REGEXP regexp3 THEN
			IF UNHEX(uuid) IS NOT NULL THEN
				SET _result = 1;
			END IF;
		END IF;
	END IF;

	RETURN _result;
END$$

SELECT IS_UUID('{decb92d4-d5bd-11ed-9a48-0800275588ea}')$$
SELECT IS_UUID('decb92d4-d5bd-11ed-9a48-0800275588ea')$$
SELECT IS_UUID('decb92d4d5bd11ed9a480800275588ea')$$

SELECT IS_UUID('XXXXXXXX-d5bd-11ed-9a48-0800275588ea')$$
SELECT IS_UUID('decb92d4d5bd-11ed-9a48-0800275588ea')$$
SELECT IS_UUID('')$$
SELECT IS_UUID(NULL)$$










DROP FUNCTION IF EXISTS UUID_TO_BIN$$

CREATE FUNCTION IF NOT EXISTS UUID_TO_BIN (uuid CHAR(36), f BOOLEAN) RETURNS BINARY(16) NO SQL DETERMINISTIC
BEGIN
	DECLARE _result BINARY(16);

	IF IS_UUID(uuid) = 1 THEN
		SET _result = UNHEX(CONCAT(IF(f, SUBSTRING(uuid, 15, 4), SUBSTRING(uuid, 1, 8)),
								   SUBSTRING(uuid, 10, 4),
								   IF(f, SUBSTRING(uuid, 1, 8), SUBSTRING(uuid, 15, 4)),
								   SUBSTRING(uuid, 20, 4),
								   SUBSTRING(uuid, 25)));
	ELSE
		SET _result = NULL;
	END IF;

	RETURN _result;
END$$










DROP FUNCTION IF EXISTS BIN_TO_UUID$$

CREATE FUNCTION IF NOT EXISTS BIN_TO_UUID (b BINARY(16), f BOOLEAN) RETURNS CHAR(36) NO SQL DETERMINISTIC
BEGIN
	DECLARE _result CHAR(36);
	DECLARE _hex CHAR(32);

	SET _hex = HEX(b);

	IF IS_UUID(_hex) = 1 THEN
		SET _result = LOWER(CONCAT(IF(f, SUBSTR(_hex, 9, 8), SUBSTR(_hex, 1, 8)), '-',
								   IF(f, SUBSTR(_hex, 5, 4), SUBSTR(_hex, 9, 4)), '-',
								   IF(f, SUBSTR(_hex, 1, 4), SUBSTR(_hex, 13, 4)), '-',
								   SUBSTR(_hex, 17, 4), '-',
								   SUBSTR(_hex, 21)));
	ELSE
		SET _result = NULL;
	END IF;

	RETURN _result;
END$$










SET @h1 = '6ccd'$$
SET @h2 = '780c'$$
SET @h3 = 'baba'$$
SET @h4 = '1026'$$
SET @h5 = '9564'$$
SET @h6 = '5b8c'$$
SET @h7 = '6560'$$
SET @h8 = '24db'$$

SET @uuid = LOWER(CONCAT(@h1, @h2, '-', @h3, '-', @h4, '-', @h5, '-', @h6, @h7, @h8))$$

SET @uux0 = UPPER(REPLACE(@uuid, '-', ''))$$
SET @uux1 = LOWER(CONCAT(@h4, @h3, @h1, @h2, @h5, @h6, @h7, @h8))$$

SET @bin0 = UUID_TO_BIN(@uuid, 0)$$
SET @bin1 = UUID_TO_BIN(@uuid, 1)$$

SET @hex0 = HEX(@bin0)$$
SET @hex1 = HEX(@bin1)$$

SET @uui0 = BIN_TO_UUID(@bin0, 0)$$
SET @uui1 = BIN_TO_UUID(@bin1, 1)$$

SELECT @bin0, @hex0, if(@hex0 = @uux0, 'OK', 'ERROR')$$
SELECT @bin1, @hex1, if(@hex1 = @uux1, 'OK', 'ERROR')$$
SELECT @uui0, @uuid, if(BINARY @uui0 = BINARY @uuid, 'OK', 'ERROR')$$
SELECT @uui1, @uuid, if(BINARY @uui1 = BINARY @uuid, 'OK', 'ERROR')$$










DROP FUNCTION IF EXISTS UUID_NS$$

CREATE FUNCTION IF NOT EXISTS UUID_NS (v SMALLINT, ns VARCHAR(36), name VARCHAR(2000)) RETURNS CHAR(36) NO SQL DETERMINISTIC
BEGIN
	DECLARE _result CHAR(36);
	DECLARE x VARCHAR(255);
	DECLARE ns_bin BINARY(16);
	DECLARE prehash_value BLOB;
	DECLARE hashed_value VARCHAR(255);
	DECLARE time_hi BIGINT UNSIGNED;
	DECLARE clock_seq_hi BIGINT UNSIGNED;
	DECLARE time_low CHAR(8);
	DECLARE time_mid CHAR(4);
	DECLARE time_hi_and_version CHAR(4);
	DECLARE clock_seq_hi_and_reserved CHAR(2);
	DECLARE clock_seq_low CHAR(2);
	DECLARE clock_seq CHAR(4);
	DECLARE node CHAR(12);

	IF (v = 3 OR v = 5) AND IS_UUID(ns) AND CHAR_LENGTH(name) > 0 THEN
		SET ns_bin = UUID_TO_BIN(ns, 0);
		SET prehash_value = CONCAT(ns_bin, name);
		
		IF v = 3 THEN
			SET hashed_value = MD5(prehash_value);
		ELSE
			IF v = 5 THEN
				SET hashed_value = SHA1(prehash_value);
			ELSE
				SET hashed_value = NULL;
			END IF;
		END IF;

		SET x = MID(hashed_value, 13, 4);
		SET time_hi = CONV(x, 16, 10) & 0x0fff;
		SET time_hi = time_hi & ~(0xf000);
		SET time_hi = time_hi | (v << 12);

		SET x = MID(hashed_value, 17, 2);
		SET clock_seq_hi = CONV(x, 16, 10);
		SET clock_seq_hi = clock_seq_hi & 0x3f;
		SET clock_seq_hi = clock_seq_hi & ~(0xc0);
		SET clock_seq_hi = clock_seq_hi | 0x80;

		SET time_low = LEFT(hashed_value, 8);
		SET time_mid = MID(hashed_value, 9, 4);
		SET time_hi_and_version = lpad(conv(time_hi, 10, 16), 4, '0');
		SET clock_seq_hi_and_reserved = lpad(conv(clock_seq_hi, 10, 16), 2, '0');
		SET clock_seq_low = MID(hashed_value, 19, 2);
		SET node = lpad(MID(hashed_value, 21, 12), 12, '0');

		SET clock_seq = CONCAT(clock_seq_hi_and_reserved, clock_seq_low);

		SET _result = LOWER(CONCAT_WS('-', time_low, time_mid, time_hi_and_version, clock_seq, node));
	ELSE
		SET _result = NULL;
	END IF;

	RETURN _result;
END$$










DROP FUNCTION IF EXISTS UUID_V3$$

CREATE FUNCTION IF NOT EXISTS UUID_V3 (ns VARCHAR(36), name VARCHAR(2000)) RETURNS CHAR(36) NO SQL DETERMINISTIC
BEGIN
	RETURN UUID_NS(3, ns, name);
END$$

SELECT UUID_V3('6ccd780c-baba-1026-9564-5b8c656024db', 'SomeDNS')$$
SELECT UUID_V3('6ccd780c-baba-1026-9564-5b8c656024db', 'SomeURL')$$
SELECT UUID_V3('6ccd780c-baba-1026-9564-5b8c656024db', 'SomeOID')$$
SELECT UUID_V3('6ccd780c-baba-1026-9564-5b8c656024db', 'SomeX500')$$










DROP FUNCTION IF EXISTS UUID_V5$$

CREATE FUNCTION IF NOT EXISTS UUID_V5 (ns VARCHAR(36), name VARCHAR(2000)) RETURNS CHAR(36) NO SQL DETERMINISTIC
BEGIN
	RETURN UUID_NS(5, ns, name);
END$$

SELECT UUID_V5('6ccd780c-baba-1026-9564-5b8c656024db', 'SomeDNS')$$
SELECT UUID_V5('6ccd780c-baba-1026-9564-5b8c656024db', 'SomeURL')$$
SELECT UUID_V5('6ccd780c-baba-1026-9564-5b8c656024db', 'SomeOID')$$
SELECT UUID_V5('6ccd780c-baba-1026-9564-5b8c656024db', 'SomeX500')$$










DROP FUNCTION IF EXISTS UUID_V4$$

CREATE FUNCTION IF NOT EXISTS UUID_V4 () RETURNS CHAR(36) NO SQL
BEGIN
	-- Indicates the UUID version
	DECLARE v CHAR(1);

	-- Declares the UUID's parts
	DECLARE h1 CHAR(4);
	DECLARE h2 CHAR(4);
	DECLARE h3 CHAR(4);
	DECLARE h4 CHAR(4);
	DECLARE h5 CHAR(4);
	DECLARE h6 CHAR(4);
	DECLARE h7 CHAR(4);
	DECLARE h8 CHAR(4);

	-- Sets the UUID's version
	SET v = '4';

    -- Generates random strings that will form the UUID's 12 first and 12 last chars
    SET h1 = LPAD(HEX(FLOOR(RAND() * 0xffff)), 4, '0');
    SET h2 = LPAD(HEX(FLOOR(RAND() * 0xffff)), 4, '0');
    SET h3 = LPAD(HEX(FLOOR(RAND() * 0xffff)), 4, '0');
    SET h6 = LPAD(HEX(FLOOR(RAND() * 0xffff)), 4, '0');
    SET h7 = LPAD(HEX(FLOOR(RAND() * 0xffff)), 4, '0');
    SET h8 = LPAD(HEX(FLOOR(RAND() * 0xffff)), 4, '0');

    -- 4th section starts with the UUID's version
    SET h4 = CONCAT(v, LPAD(HEX(FLOOR(RAND() * 0x0fff)), 3, '0'));

    -- 5th section's first half-byte can only be 8, 9, A or B
    SET h5 = CONCAT(HEX(FLOOR(RAND() * 4 + 8)), LPAD(HEX(FLOOR(RAND() * 0x0fff)), 3, '0'));

    -- Builds the complete UUID
    RETURN LOWER(CONCAT(h1, h2, '-', h3, '-', h4, '-', h5, '-', h6, h7, h8));
END $$

SELECT UUID_V4()$$










DROP FUNCTION IF EXISTS UUID_V7$$

CREATE FUNCTION IF NOT EXISTS UUID_V7 () RETURNS CHAR(36) NO SQL
BEGIN
	-- Indicates the UUID version
	DECLARE v CHAR(1);

	-- Declares the UUID's parts
	DECLARE h1 CHAR(4);
	DECLARE h2 CHAR(4);
	DECLARE h3 CHAR(4);
	DECLARE h4 CHAR(4);
	DECLARE h5 CHAR(4);
	DECLARE h6 CHAR(4);
	DECLARE h7 CHAR(4);
	DECLARE h8 CHAR(4);

	-- Timestamp
	DECLARE ts BIGINT;

	-- Timestamp in an hexadecimal representation
	DECLARE tx VARCHAR(255);

	-- Random bytes
	DECLARE rb2 CHAR(4);
	DECLARE rb8 CHAR(16);

	-- Variant bits
	DECLARE vb SMALLINT;

	-- Variant bits in an hexadecimal representation
	DECLARE vh CHAR(1);

	-- Sets the UUID's version
	SET v = '7';

	-- Uses NOW(3) to get milliseconds
	SET ts = UNIX_TIMESTAMP(NOW(3)) * 1000;
	SET tx = LPAD(HEX(ts), 12, '0');

	SET rb2 = HEX(RANDOM_BYTES(2));
	SET rb8 = HEX(RANDOM_BYTES(8));

	SET vb = FLOOR(RAND() * 4 + 8);
	SET vh = HEX(vb);

	SET h1 = SUBSTRING(tx, 1, 4);
	SET h2 = SUBSTRING(tx, 5, 4);
	SET h3 = SUBSTRING(tx, 9, 4);

    -- 4th section starts with the UUID's version
	SET h4 = CONCAT(v, SUBSTRING(rb2, 2, 3));

	SET h5 = CONCAT(vh, SUBSTRING(rb8, 2, 3));
	SET h6 = SUBSTRING(rb8, 5, 4);
	SET h7 = SUBSTRING(rb8, 9, 4);
	SET h8 = SUBSTRING(rb8, 13, 4);

    -- Builds the complete UUID
	RETURN LOWER(CONCAT(h1, h2, '-', h3, '-', h4, '-', h5, '-', h6, h7, h8));
END $$

SELECT UUID_V7()$$










DROP FUNCTION IF EXISTS UUID_EMPTY$$
DROP FUNCTION IF EXISTS UUID_NIL$$
DROP FUNCTION IF EXISTS UUID_MAX$$
DROP FUNCTION IF EXISTS UUID_OMNI$$

CREATE FUNCTION IF NOT EXISTS UUID_EMPTY () RETURNS CHAR(36) NO SQL DETERMINISTIC
BEGIN
	RETURN '00000000-0000-0000-0000-000000000000';
END $$

CREATE FUNCTION IF NOT EXISTS UUID_NIL () RETURNS CHAR(36) NO SQL DETERMINISTIC
BEGIN
	RETURN UUID_EMPTY();
END $$

CREATE FUNCTION IF NOT EXISTS UUID_MAX () RETURNS CHAR(36) NO SQL DETERMINISTIC
BEGIN
	RETURN 'ffffffff-ffff-ffff-ffff-ffffffffffff';
END $$

CREATE FUNCTION IF NOT EXISTS UUID_OMNI () RETURNS CHAR(36) NO SQL DETERMINISTIC
BEGIN
	RETURN UUID_MAX();
END $$

SELECT UUID_EMPTY()$$
SELECT UUID_NIL()$$
SELECT UUID_MAX()$$
SELECT UUID_OMNI()$$












DELIMITER ;
