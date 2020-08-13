--! @file generator_signala.vhd
--! @brief Generator pravougaonog ili trougaonog signala
--! @details Ovaj fajl opisuje generator signala(trouglova ili cetvrtki). Fajl sadrzi opis interfejsa komponente i 
--! odgovarajuce arhitekture \n
--! @author Jelena Urosevic\n Stefan Vukasinovic
--! @date 12/12/2016
--! @version 1.0


library ieee;
use ieee.std_logic_1164.all;


--! @brief Deklaracija entitija za generator_signala
--! @details 
--! Genrator signala je sekvencijalna komponenta koja generise 16-bitni izlaz, 
--! koji predstavlja odbirak koji se salje na ulazni registar D/A konvertora.
--! Faktor ispunjenosti signala na izlazu D/A konvertora se moze podesavati pomocu tastera napred i nazad
--! u koracima od po 10%, dok se oblik izlaznog signala podesava pomocu prekidaca. 
--! Interfejs ove komponente je prikazan na Fig. 1. \n
--! @image html generatorSignala.png "Fig. 1. Blok simbol komponente generator_signala"

entity generator_signala is
port(
	--! clk signal 
	clk: in std_logic;
	--! asinhroni reset
	reset: in std_logic;
	--! taster napred za uvecanje faktora ispunjenosti
	napred: in std_logic;
	--! taster nazad za smanjenje faktora ispunjenosti
	nazad: in std_logic;
	--! prekidac za izbor oblika izlaznog signala 
	prekidac: in std_logic;
	--! paralelni izlaz
	mux_out: out std_logic_vector(15 downto 0)
);
end generator_signala;

--! @brief opis arhitekture za generator_signala
--! @details
--! Blok sema generatora signala je prikazana na Fig. 1. Ova komponenta je realizovana kao kompleksan sistem koji se sastoji od sledecih modula: generator_cetvrtki, generator_trouglova
--! i multiplekser. Izlazi komponenti generator_cetvrtki i generator_trouglova su povezani na dva ulaza multipleksera. Izlazni signal ove komponente je multipleksirana vrednost
--! nekog od dva ulaza koja zavisi od prekidaca. Tasteri napred i nazad sluze za podesavanje faktora ispunjenosti. 
--! @image html generatorSignala_block_scheme.png "Fig. 1. Blok sema komponente generator_signala."

architecture behav of generator_signala is

component generator_cetvrtki is
port(
	--! clk signal 
	clk: in std_logic;
	--! asinhroni reset
	reset: in std_logic;
	--! taster napred za uvecanje faktora ispunjenosti
	napred: in std_logic;
	--! taster nazad za smanjenje faktora ispunjenosti
	nazad: in std_logic;
	--! paralelni izlaz
	cetvrtke_out: out std_logic_vector(15 downto 0)
);
end component;

component generator_trouglova is
port(
	--! clk signal 
	clk: in std_logic;
	--! asinhroni reset
	reset: in std_logic;
	--! taster napred za uvecanje faktora ispunjenosti
	napred: in std_logic;
	--! taster nazad za smanjenje faktora ispunjenosti
	nazad: in std_logic;
	--! paralelni izlaz
	truglovi_out: out std_logic_vector(15 downto 0)
);
end component;

component multiplekser is
generic (N: natural := 16);

	port
	(
		--! Input ports
		a0,a1	: in  std_logic_vector(N-1 downto 0);
		sel	: in  std_logic;
			--! Output port
		y	: out std_logic_vector(N-1 downto 0)
	);
end component;

signal da_input_cetvrtke: std_logic_vector(15 downto 0);
signal da_input_trouglovi: std_logic_vector(15 downto 0);

begin

cetvrtke_inst: generator_cetvrtki port map(clk, reset, napred,nazad, da_input_cetvrtke);
trouglovi_inst: generator_trouglova port map(clk,reset,napred,nazad, da_input_trouglovi);
mux_inst: multiplekser port map(da_input_cetvrtke, da_input_trouglovi, prekidac, mux_out);

end behav;