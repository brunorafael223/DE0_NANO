LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY controlador_I2C_CMPS10 IS
PORT (
	CLK_50_MHz: IN STD_LOGIC;
	
	--Sinais de controlo
	SCL: OUT STD_LOGIC;
	SDA: INOUT STD_LOGIC;
	--fim_ciclo: out STD_LOGIC; -- marca o fim de um ciclo para que se possam ler varios registos
	DataBussolaOut: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	DataPitchOut: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	DataRollOut: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	DataZOut: OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END controlador_I2C_CMPS10;

ARCHITECTURE behavior OF controlador_I2C_CMPS10 IS

	SIGNAL state: 			STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000000";
	SIGNAL RegisterAddress: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL Data: 			STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL SDA01: 			STD_LOGIC; -- SDA interno
	
	SIGNAL   bitcount: INTEGER RANGE 0 TO 7;
	CONSTANT RegAddrBussola: 	STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000001"; -- 1
	CONSTANT RegAddrPitch: 	 	STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000100"; -- 4
	CONSTANT RegAddrRoll:    	STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000101"; -- 5
	CONSTANT RegAddrZ:       	STD_LOGIC_VECTOR(7 DOWNTO 0) := "00010100"; -- 20
	CONSTANT SlaveAddress_Read: STD_LOGIC_VECTOR(7 DOWNTO 0) := "1100000"&'1';	-- I2C address of the slave + read
	CONSTANT SlaveAddress_Write:STD_LOGIC_VECTOR(7 DOWNTO 0) := "1100000"&'0';	-- I2C address of the slave + write'
	CONSTANT NumberOfRegisters: STD_LOGIC_VECTOR(7 DOWNTO 0) := x"17";	-- total number of registers in the slave
	
	SIGNAL reg: INTEGER := 0;
	SIGNAL max400k		:STD_LOGIC_VECTOR(8 DOWNTO 0):="000000000"; -- 124 in binary 1111100
	SIGNAL CLK_400k_Hz: STD_LOGIC;
	SIGNAL CLK_EVEN: STD_LOGIC := '0';
	
	BEGIN

	SDA <= 'Z' WHEN SDA01 = '1' ELSE '0';	-- convert SDA 0/1 to 0/Z
	
	-- Processo que gera um clock de 400KHz para freq. de comunicação
	clk_div_400k: PROCESS
	BEGIN
		WAIT UNTIL CLK_50_MHz'EVENT and CLK_50_MHz = '1';
			IF max400k = 500 THEN
				CLK_400k_Hz <= '1';
			ELSE
				CLK_400k_Hz <= '0';
			END IF;
			
			IF max400k < 500 THEN
				max400k <= max400k + 1;
			ELSE
				max400k <= "000000000";
			END IF;
	END PROCESS;
	
	-- Processo que comunica com o CMPS10
	output: PROCESS(CLK_400k_Hz)
	BEGIN
		IF(CLK_400k_Hz'EVENT and CLK_400k_Hz = '1') THEN
			CASE state IS
			WHEN x"00" =>	-- em stand by
				-- neste caso, ambos SDA e SCL = 1
				SCL <= 'Z';
				SDA01 <= '1';
				--DataBussolaOut <= "00000000";
				--DataPitchOut <= "00000000";
				--DataRollOut <= "00000000";
				--DataZOut <= "00000000";
				state <= x"01";
				
----------------------------------------------------------------				
-- enviar start sequence e endereço do sensor
			WHEN x"01" =>	-- Começa
				-- SCL fica a 1 enquanto o SDA muda de 1 para 0 (o SDA já está a 1 do estado anterior)
				SCL <= '1';	
				SDA01 <= '0';
				bitcount <= 7;	-- inicializar o bit count
				state <= x"02";
				
			-- envia o endereço do sensor seguido do bit leitura/escrita
			WHEN x"02" =>					
				SCL <= '0';
				-- neste caso queremos escrever o endereço do sensor para a linha logo utilizamos o endereço
				-- do sensor com o bit de escrita
				SDA01 <= SlaveAddress_Write(bitcount);
				state <= x"03";
			WHEN x"03" =>
				SCL <= '1';
				-- se ainda nao tiver lido tudo volta atrás com o bit count decrementado
				IF (bitcount - 1) >= 0 THEN
					bitcount <= bitcount - 1;
					state <= x"02";
				ELSE -- senão reinicializa o bitcount a 7 e passa ao proximo passo
					bitcount <= 7;
					state <= x"12";
				END IF;
			-- um ciclo de clock para obter o ACK do escravo
			WHEN x"12" =>
				SCL <= '0';
				SDA01 <= '1';
				state <= x"13";
			WHEN x"13" =>
				SCL <= '1';
				IF SDA = '1' THEN
					state <= x"EE";	-- salta para o estado de erro caso detete erro de ACK
				ELSE
					state <= x"20";	-- senao passa ao proximo estado
				END IF;

----------------------------------------------------------------
			-- send 8-bit register address to slave
			-- enviar o endereço do registo que queremos ler para o escravo
			-- analogamente à maneira de como enviamos o endereço para escrita
			WHEN x"20" =>
				SCL <= '0';
				-- vamos ler os registos todos seguidos
				-- vamos por reg = 0 que significa que estamos a ler o primeiro registo
				-- depois vamos por reg = 1 para que leia outro registo no ciclo seguinte
				-- por assim em diante ate ler todos os registos interessantes
				-- voltar a por reg = 0;
				IF(reg = 0) then
					SDA01 <= RegAddrBussola(bitcount);
				ELSIF(reg = 1) then
					SDA01 <= RegAddrPitch(bitcount);
				ELSIF(reg = 2) then
					SDA01 <= RegAddrRoll(bitcount);
				ELSIF(reg = 3) then
					SDA01 <= RegAddrZ(bitcount);
				END IF;
				state <= x"21";
			WHEN x"21" =>
				SCL <= '1';
				IF (bitcount - 1) >= 0 THEN
					bitcount <= bitcount - 1;
					state <= x"20";
				ELSE
					bitcount <= 7;
					state <= x"30";
				END IF;
			-- obter o ack bit
			WHEN x"30" =>
				SCL <= '0';
				SDA01 <= '1';
				state <= x"31";
			WHEN x"31" =>
				SCL <= '1';
				--RegisterAddress <= AddressIn;
				IF SDA = '1' THEN
					--RegisterAddressOut <= x"31";
					state <= x"EE"; -- erro
				ELSE
					state <= x"70";	-- manda outro start sequence e lê do registo cujo endereço acabámos de enviar
				END IF;

----------------------------------------------------------------
-- receber os dados do sensor
			-- enviar um novo start sequence porque queremos ler depois de ter feito uma escrita
			-- SDA vai de 1 a 0 enquanto SCL é 1
			WHEN x"70" =>
				SCL <= '0';
				SDA01 <= '1';
				IF SDA = '1' THEN -- verificar o ack error
					state <= x"EE";
				ELSE
					state <= x"71"; -- continua
				END IF;
			WHEN x"71" =>
				SCL <= '1';
				SDA01 <= '1';
				state <= x"72";
			WHEN x"72" =>
				SCL <= '1';
				SDA01 <= '0';
				bitcount <= 7;
				state <= x"82";
			-- enviar o endereço do chip cujo registos queremos ler com o bit leitura/escrita em leitura
			WHEN x"82" =>					
				SCL <= '0';
				SDA01 <= SlaveAddress_Read(bitcount);
				state <= x"83";
			WHEN x"83" =>
				SCL <= '1';
				IF (bitcount - 1) >= 0 THEN
					bitcount <= bitcount - 1;
					state <= x"82";
				ELSE
					bitcount <= 7;
					state <= x"92";
				END IF;
			-- obter o ACK
			WHEN x"92" =>
				SCL <= '0';
				SDA01 <= '1';
				state <= x"93";
			WHEN x"93" =>
				SCL <= '1';
				IF SDA = '1' THEN
					state <= x"EE";	-- erro de ACK
				ELSE
					bitcount <= 7;
					state <= x"C0";	-- continua
				END IF;


----------------------------------------------------------------
			-- recebe os bytes do registo
			WHEN x"C0" =>
				SCL <= '0';
				SDA01 <= '1';
				state <= x"C1";
			WHEN x"C1" =>
				SCL <= '1';
				Data(bitcount) <= SDA;	-- lê os dados bit a bit
				IF (bitcount - 1) >= 0 THEN
					bitcount <= bitcount - 1;
					state <= x"C0";
				ELSE
					bitcount <= 7;
					state <= x"D0";
				END IF;
			-- se ainda houver bytes para ler entao mandamos um ack a 0
			-- caso contrario então mandamos um ack a 1
			WHEN x"D0" =>
				SCL <= '0';
				IF (RegisterAddress = RegisterAddress) THEN			-- read only one byte
--				IF (RegisterAddress + 1 > NumberOfRegisters) THEN	-- read multi-bytes
					-- read last byte
					SDA01 <= '1';	-- enviar ack a 1
					state <= x"D2";	-- estado onde para de ler
				ELSE
					-- read next byte
					RegisterAddress <= RegisterAddress + 1;
					SDA01 <= '0';	-- ack a 0
					state <= x"D1";	-- estado onde continua a ler o proximo byte
				END IF;
				IF(reg = 0) THEN
					DataBussolaOut <= Data;
				END IF;
				IF(reg = 1) THEN
					DataPitchOut <= Data;
				END IF;
				IF(reg = 2) THEN
					DataRollOut <= Data;
				END IF;
				IF(reg = 3) THEN
					DataZOut <= Data;
				END IF;
				
				IF(reg = 0) THEN
					reg <= 1;
				ELSIF(reg = 1) THEN
					reg <= 2;
				ELSIF(reg = 2) THEN
					reg <= 3;
				ELSE
					reg <= 0;
				END IF;
			WHEN x"D1" =>
				SCL <= '1';
				state <= x"C0";

			-----------------------------------------------------------
			-- enviar um ACK a 1
			WHEN x"D2" =>
				SCL <= '1';
				state <= x"D3";
			-- manda um stop sequence
			-- SDA vai de 0 a 1 enquanto SCL é 1
			WHEN x"D3" =>
				SCL <= '0';
				SDA01 <= '0';
				state <= x"D4";
			WHEN x"D4" =>
				SCL <= '1';
				SDA01 <= '0';
				state <= x"D5";
			WHEN x"D5" =>
				SCL <= '1';
				SDA01 <= '1';
				--state <= x"D5";
				--state <= x"00";
				state <= x"D6";
			WHEN x"D6" =>
				SCL <= 'Z';
				SDA01 <= '1';
				--DataOut <= "00000000";
				state <= x"00";

-----------------------------------------------------------
			-- estado de erros de ACK
			WHEN x"EE" =>
				SCL <= '1';
				SDA01 <= '1';
				DataBussolaOut <= x"EE";
				DataPitchOut <= x"EE";
				DataRollOut <= x"EE";
				DataZOut <= x"EE";


-----------------------------------------------------------
			-- espera que o BUS I2C fique em stand by esperando que o SDA fique 1 durante pelo menos 8 ciclos de SCL
			WHEN x"F0" =>
				SCL <= '0';
				bitcount <= 7;
				state <= x"F1";
			WHEN x"F1" =>
				SCL <= '1';
				IF SDA = '0' THEN
					bitcount <= 7;
				ELSE
					bitcount <= bitcount - 1;
				END IF;
				state <= x"F2";
			WHEN x"F2" =>
				SCL <= '0';
				IF bitcount = 0 THEN
					state <= x"00";
				ELSE
					state <= x"F1";
				END IF;
				
			WHEN OTHERS => null;
				SCL <= '1';
				SDA01 <= '1';
			END CASE;
		END IF;
	END PROCESS;
	
END behavior;
