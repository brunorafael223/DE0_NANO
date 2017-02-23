LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY top_level IS
PORT 
(
	CLOCK_50: IN 		STD_LOGIC;
	I2C_SCLK: OUT 		STD_LOGIC;
	I2C_SDAT: INOUT	STD_LOGIC;
	LED	  : OUT 		STD_LOGIC_VECTOR(7 DOWNTO 0)
);
END top_level;

ARCHITECTURE behavior OF top_level IS

-- ====================================================
--						     COMPONENTS
-- ====================================================

COMPONENT ADXL345_I2C is 
	PORT(
			 clk 	: in std_logic;
			 reset : in std_logic;
	);
END COMPONENT;
-- ====================================================
--								SIGNAL
-- ====================================================

BEGIN

END behavior;