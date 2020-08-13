--! @file DAKonvertor_generatorSignala.vhd
--! @brief D/A Konvertor - generator signala
--! @details Top level dizajn sistema. Spaja sve prethodno definisane module i vrsi komunikaciju sa LTC2607
--! plocicom D/A konvertora saljuci joj odbirke po definisanom protokolu sa I2C interfejsom i na izlazu D/A
--! konvertora ostvaruje izlazni analogni signal. Oblik generisanog signala(cetvrtke/trouglovi) se moze
--! podesavati pozicijom prekidaca, dok se pritiskom na tastere napred ili nazad vrsi promena faktora ispunjesti
--! izlaznog signala za 10%. U ovom fajlu se nalaze opis interfejsa komponente i njegova njena arhitektura \n
--! @author Jelena Urosevic\n Stefan Vukasinovic
--! @date 12/12/2016
--! @version 1.0
--! @image html DAK_generatorSignalatiming_diagram.png "Fig. 1. Vremenski dijagram - SDA i SCL za SA[6..0]=0010000 i CA[7..0]=00110000 i 16-bitni odbirak sa vrednoscu 0"\n

library ieee;
use ieee.std_logic_1164.all;

--! @brief Deklaracija entitija za DAKonvertor_generatorSignala
--! @details 
--! Oblik generisanog signala(cetvrtke/trouglovi) se moze podesavati pozicijom prekidaca, 
--! dok se pritiskom na tastere napred ili nazad vrsi promena faktora ispunjesti izlaznog signala za 10%
--! Blok simbol komonente je prikazan na Fig. 1.
--! @image html DAK_generatorSignala.png "Fig. 1. Blok simbol komponente DAKonvertor_generatorSignala"

entity DAKonvertor_generatorSignala is
port(
	--! clk signal 
	clk: in std_logic;
	--! asinhroni reset
	reset: in std_logic;
	--! taster napred za uvecanje faktora ispunjenosti
	napred: in std_logic;
	--! taster nazad za smanjenje faktora ispunjenosti
	nazad: in std_logic;
	--! prekidac 
	prekidac: in std_logic;
	--! ulazno-izlazni signal
	sda	: out std_logic;
	--! izlazni signal
	scl	: out std_logic	
);

end DAKonvertor_generatorSignala;

--! @brief opis arhitekture za DAKonvertor_generatorSignala
--! @details
--! Blok sema komponente DAKonvertor_generatorSignala je prikazana na Fig. 1. Ova komponenta je realizovana
--! kao kompleksan sistem koji se sastoji od sledecih modula: generator_signala, ulazni_reg i kontroler.
--! Izlaz komponente generator_signala je povezan na ulazni registar D/A konvertora. Izlaz ulaznog registra
--! D/A konvertora je potom povezan na ulaz komponente kontroler. Signal load_data komponente kontroler kontrolise
--! upis novog odbirka iz ulaznog registra D/A konvertora u modul kontrolera koji taj odbirak salje na ulaz D/A konvertora
--! prema definisanom protokolu
--! @image html DAK_generatorSignala_block_scheme.png "Fig. 1. Blok sema komponente DAKonvertor_generatorSignala."

architecture behav of DAKonvertor_generatorSignala is

component generator_signala is
port(
	-- Input ports
	clk,reset: in std_logic;
	napred,nazad: in std_logic;
	prekidac: in std_logic;
	-- Output ports
	mux_out: out std_logic_vector(15 downto 0)
);
end component;

component ulazni_reg is
port(
	-- Input ports
	reg_in: in std_logic_vector(15 downto 0);
	clr: in std_logic; -- async. clear
	clk: in std_logic; -- clock
	ld: in std_logic; -- load/enable
	-- Output ports
	reg_out: out std_logic_vector(15 downto 0)
);
end component;

component kontroler is
port(
	-- Input ports
	clk,reset: in std_logic;	
	data_in: in std_logic_vector(15 downto 0);
	-- Inout ports
	SDA	: out std_logic;
	-- Output ports
	SCL	: out std_logic;
	load_data: out std_logic --vodi se na enable ulaznog REG
);
end component;

component detektor is
port(
		clk,reset: in std_logic;
	   taster: in std_logic;
		zahtev: out std_logic
);
end component;

signal DETEKTOR_NAPRED: std_logic;
signal DETEKTOR_NAZAD: std_logic;
signal DATA_REG_OUT: std_logic_vector(15 downto 0);--odbirak koji se salje na D/A konvertor,izlaz prihv.registra
signal ENABLE_REG: std_logic;--signal koji salje kontroler prema REG-u kada je spreman za novi odbirak
signal DATA_MUX_OUT: std_logic_vector(15 downto 0);

begin

detektor1_inst: detektor port map(clk, reset, napred, DETEKTOR_NAPRED);
detektor2_inst: detektor port map(clk, reset, nazad, DETEKTOR_NAZAD);
generator_signala_inst: generator_signala port map(clk, reset, DETEKTOR_NAPRED, DETEKTOR_NAZAD, prekidac, DATA_MUX_OUT);
ulazni_reg_inst: ulazni_reg port map(DATA_MUX_OUT, reset, clk, ENABLE_REG, DATA_REG_OUT);
kontroler_inst: kontroler port map(clk, reset, DATA_REG_OUT, sda, scl, ENABLE_REG);

end behav;