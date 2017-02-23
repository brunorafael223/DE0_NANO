

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY ADXL345_I2C IS
PORT 
(
	CLOCK_50: IN STD_LOGIC;

	I2C_SCLK: OUT STD_LOGIC;
	I2C_SDAT: INOUT STD_LOGIC;
	
	LED  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	
);
END ADXL345_I2C;

ARCHITECTURE behavior OF ADXL345_I2C IS

	SIGNAL CLK_400: 		STD_LOGIC;
	SIGNAL SDA: 			STD_LOGIC; 						
	SIGNAL SCL:				STD_LOGIC;
 	
	type 	 STATE_TYPE is (i0,i1,i2,i3,i4,i5,i6,i7,i8,i9,a0,a1,a2,a3,a4,a5,a6,c0,c1,d0,d1,d2,d3,d4,d5,d6,er,f0,f1,f2);
	signal state: STATE_TYPE:= i0;
	
 	SIGNAL bitcount: 		INTEGER  RANGE 0 TO 7;
	SIGNAL counter: 		NATURAL := 0; 
		
	SIGNAL Data: 			STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL DataX0: 		STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL DataX1: 		STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL DataY0: 		STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL DataY1: 		STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL DataZ0: 		STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL DataZ1: 		STD_LOGIC_VECTOR(7 DOWNTO 0);
	
	SIGNAL X: 				STD_LOGIC_VECTOR(9 DOWNTO 0);
	SIGNAL Y: 				STD_LOGIC_VECTOR(9 DOWNTO 0);
	SIGNAL Z: 				STD_LOGIC_VECTOR(9 DOWNTO 0);
	
	SIGNAL 	reg: 			INTEGER := 0;
	SIGNAL   RegAddr: 	STD_LOGIC_VECTOR(7 DOWNTO 0);
	CONSTANT RegAddrX0:	STD_LOGIC_VECTOR(7 DOWNTO 0) := x"32"; -- Dec = 50
	CONSTANT RegAddrX1: 	STD_LOGIC_VECTOR(7 DOWNTO 0) := x"33"; -- Dec = 51
	CONSTANT RegAddrY0:	STD_LOGIC_VECTOR(7 DOWNTO 0) := x"34"; -- Dec = 52
	CONSTANT RegAddrY1:	STD_LOGIC_VECTOR(7 DOWNTO 0) := x"35"; -- Dec = 53
	CONSTANT RegAddrZ0: 	STD_LOGIC_VECTOR(7 DOWNTO 0) := x"36"; -- Dec = 54
	CONSTANT RegAddrZ1: 	STD_LOGIC_VECTOR(7 DOWNTO 0) := x"37"; -- Dec = 55

	CONSTANT SlaveAddress_Write:STD_LOGIC_VECTOR(7 DOWNTO 0) := x"3A";	-- I2C address of the slave + write
	CONSTANT SlaveAddress_Read: STD_LOGIC_VECTOR(7 DOWNTO 0) := x"3B";	-- I2C address of the slave + read
	
	SIGNAL max400k		:STD_LOGIC_VECTOR(8 DOWNTO 0):="000000000"; -- 124 in binary 1111100
	
BEGIN
	
	I2C_SCLK <= SCL;
	I2C_SDAT <= 'Z' WHEN SDA = '1' ELSE '0';	
	
	--X <= DataX0(1 DOWNTO 0 ) & DataX1;
	--Y <= DataY0(1 DOWNTO 0 ) & DataY1;
	--Z <= DataZ0(1 DOWNTO 0 ) & DataZ1;
	LED  <= DataX0;
	
	clk_div_400k: PROCESS
	BEGIN
		WAIT UNTIL CLOCK_50'EVENT and CLOCK_50 = '1';
			IF max400k = 500 THEN
				CLK_400 <= '1';
			ELSE
				CLK_400 <= '0';
			END IF;
			
			IF max400k < 500 THEN
				max400k <= max400k + 1;
			ELSE
				max400k <= "000000000";
			END IF;
	END PROCESS;
			
	-- ADXL345 output comunication process
 	output: PROCESS(CLK_400)
 	
	BEGIN

		IF(CLK_400'EVENT and CLK_400 = '1') THEN
			
			CASE state IS
			----------------------------------------------------------------		
			WHEN i0 =>	SCL<='Z'; SDA <='1'; state <= i1;	
			----------------------------------------------------------------				
			WHEN i1 =>	SCL<='1'; SDA <='0'; state <= i2; bitcount <= 7 ;	
			----------------------------------------------------------------		
			WHEN i2 =>	SCL<='0';		
			
				SDA   <= SlaveAddress_Write(bitcount);
				state <= i3;
				
			----------------------------------------------------------------
			WHEN i3 =>	SCL<='1';
				
				IF (bitcount - 1) >= 0 THEN	
					bitcount  <= bitcount - 1;
					state <= i2;			  
				ELSE 
					bitcount  <= 7;				
					state <= i4;
				END IF;
				
			----------------------------------------------------------------
			WHEN i4 =>	SCL<='0'; SDA <='1'; state <= i5;
			----------------------------------------------------------------
			WHEN i5 =>	SCL<='1';	
			
				IF I2C_SDAT = '1' THEN	
					state <= er;	
				ELSE								
					state <= i6;	
				END IF;
		   
			----------------------------------------------------------------
			WHEN i6 =>	SCL<='0';

				CASE reg IS
					WHEN 0 => SDA <= RegAddrX0(bitcount); 
					WHEN 1 => SDA <= RegAddrX1(bitcount); 
					WHEN 2 => SDA <= RegAddrY0(bitcount); 
					WHEN 3 => SDA <= RegAddrY1(bitcount); 
					WHEN 4 => SDA <= RegAddrZ0(bitcount); 
					WHEN 5 => SDA <= RegAddrZ1(bitcount); 
					WHEN OTHERS => state <= er;
				END CASE;
				
				state   <= i7;
				
			----------------------------------------------------------------
			WHEN i7 =>  SCL<='1';

				IF (bitcount - 1) >= 0 THEN
					bitcount <= bitcount - 1;
					state 	<= i6;
				ELSE
					bitcount <= 7;
					state 	<= i8;
				END IF;
				
			----------------------------------------------------------------
			WHEN i8 => SCL<='0'; SDA <='1'; state <= i9;
			----------------------------------------------------------------
			WHEN i9 => SCL<='1';

				IF I2C_SDAT = '1' THEN
					state <= er;
				ELSE
					state <= a0;	
				END IF;
				
			----------------------------------------------------------------
			-- Receber os dados do sensor
			----------------------------------------------------------------
			WHEN a0 =>	SCL<='0'; SDA <='1';
				
				IF I2C_SDAT = '1' THEN 
					state <= er;
				ELSE
					state <= a1; 
				END IF;
				
			----------------------------------------------------------------	
			WHEN a1 => SCL<='1'; SDA <='1'; state <= a2;
			----------------------------------------------------------------
			WHEN a2 => SCL<='1'; SDA <='0'; state <= a3; bitcount <= 7;
			----------------------------------------------------------------
			WHEN a3 =>	SCL<='0';
			
				SDA   <= SlaveAddress_Read(bitcount);
				state <= a4;
			
			----------------------------------------------------------------
			WHEN a4 => SCL<='1';

				IF (bitcount - 1) >= 0 THEN
					bitcount <= bitcount - 1;
					state 	<= a3;
				ELSE
					bitcount <= 7;
					state 	<= a5;
				END IF;
				
			----------------------------------------------------------------
			-- obter o ACK
			----------------------------------------------------------------
			WHEN a5 =>	SCL<='0'; SDA <='1'; state <= a6;
			----------------------------------------------------------------
			WHEN a6 =>  SCL<='1';

				IF I2C_SDAT = '1' THEN
					state 	<= er;	
				ELSE
					bitcount <= 7;
					state    <= c0;	
				END IF;
				
			----------------------------------------------------------------
			-- recebe os bytes do registo
			----------------------------------------------------------------
			WHEN c0 =>	SCL<='0'; SDA <='1'; state <= c1;
			----------------------------------------------------------------
			WHEN c1 =>  SCL<='1';

				Data(bitcount) <= I2C_SDAT;	

				IF (bitcount - 1) >= 0 THEN
					bitcount <= bitcount - 1;
					state 	<= c0;
				ELSE
					bitcount <= 7;
					state 	<= d0;
				END IF;
				
			----------------------------------------------------------------
			WHEN d0 => SCL<='0';
				
				IF (RegAddr = RegAddr) THEN
					SDA   <= '1';	
					state <= d1;	
				ELSE
					RegAddr  <= RegAddr + 1;
					SDA   	<= '0';	
					state 	<= d2;	
				END IF;
							
				CASE reg IS
					WHEN 0 =>  DataX0 <= Data; reg <= 1;
					WHEN 1 =>  DataX1 <= Data; reg <= 2;
					WHEN 2 =>  DataY0 <= Data; reg <= 3;
					WHEN 3 =>  DataY1 <= Data; reg <= 4;
					WHEN 4 =>  DataZ0 <= Data; reg <= 5;
					WHEN 5 =>  DataZ1 <= Data; reg <= 0;
					WHEN OTHERS => reg <= 0;
				END CASE;
				
			-----------------------------------------------------------
			WHEN d1 => SCL<='1'; 			  state <= c0;
			-----------------------------------------------------------
			WHEN d2 => SCL<='1'; 			  state <= d3;
			-----------------------------------------------------------
			WHEN d3 => SCL<='0'; SDA <='0'; state <= d4;
			-----------------------------------------------------------
			WHEN d4 => SCL<='1'; SDA <='0'; state <= d5;
			-----------------------------------------------------------
			WHEN d5 => SCL<='1'; SDA <='1'; state <= d6;
			-----------------------------------------------------------
			WHEN d6 => SCL<='Z'; SDA <='1'; state <= i0;
			-----------------------------------------------------------
			-- estado de erros de ACK
			-----------------------------------------------------------
			WHEN er  => SCL<='1'; SDA <='1';
				
				DataX0 <= x"EE";
				DataX1 <= x"EE";
				DataY0 <= x"EE";
				DataY1 <= x"EE";
				DataZ0 <= x"EE";
				DataZ1 <= x"EE";
			
			-----------------------------------------------------------
			-- espera que o BUS I2C fique em stand (8 ciclos de SCL)
			-----------------------------------------------------------
			WHEN f0 => SCL<='0';
				
				bitcount <=7;
				state <= f1;
			
			-----------------------------------------------------------
			WHEN f1 => SCL<='1';
				
				IF I2C_SDAT = '0' THEN
					bitcount <= 7;
				ELSE
					bitcount <= bitcount - 1;
				END IF;
				
				state <= f2;
			-----------------------------------------------------------
			WHEN f2 => SCL<='0';

				IF bitcount = 0 THEN
					state <= i0;
				ELSE
					state <= f1;
				END IF;
				
			-----------------------------------------------------------
			WHEN OTHERS => null;
				SCL <= '1';
				SDA <= '1';
			-----------------------------------------------------------
			END CASE;

		END IF;

	END PROCESS;
	
END behavior;
