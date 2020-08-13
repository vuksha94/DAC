--! @file generator_cetvrtki.vhd
--! @brief Generator pravougaonog signala
--! @details Ovaj fajl opisuje generator pravougaonog signala. Fajl sadrzi opis interfejsa komponente i 
--! njegove arhitekture. Na Fig. 1. prikazan je vremenski dijagram generatora cetvrtki\n
--! @author Jelena Urosevic\n Stefan Vukasinovic
--! @date 12/12/2016
--! @version 1.0
--! @image html generatorCetvrtki_timing_diagram.png "Fig. 1. Vremenski dijagram generatora cetvrtki."\n

library ieee;
use ieee.std_logic_1164.all;


--! @brief Deklaracija entitija za generator_cetvrtki
--! @details 
--! Genrator cetvrtki je sekvencijalna komponenta koja generise 16-bitni izlaz, 
--! koji predstavlja odbirak koji se preko multipleksera salje na ulaz D/A konvertora.
--! Faktor ispunjenosti signala na izlazu D/A konvertora se moze podesavati pomocu tastera napred i nazad
--! u koracima od po 10%. 
--! Interfejs ove komponente je prikazan na Fig. 1. \n
--! @image html generatorCetvrtki.png "Fig. 1. Blok simbol komponente generator_cetvrtki"

entity generator_cetvrtki is
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
end generator_cetvrtki;

--! @brief opis arhitekture za generator_cetvrtki
--! @details
--! Generator cetvrtki je realizovan kao masina stanja prikazana na Fig. 1. Masina ima tri stanja: <b>sr</b>, <b>s0</b>
--! i <b>s1</b>. Stanje <b>sr</b> predstavlja stanje reseta. Po ukidanju signala reseta, masina prelazi u stanje <b>s1</b>
--! u kojem ostaje 50% perioda. U tom stanju, na izlazu se generisu sve jedinice (na ulaz D/A konvertora se dovodi maksimalna 16-bitna vrednost).
--! Ostatak perioda masina se nalazi u stanju <b>s0</b> u kojem se na 16-bitnom izlazu generisu sve nule.
--! Ukoliko je u toku perioda pritisnut taster napred ili nazad, taj dogadjaj se pamti u posebnoj promenljivoj,
--! i na kraju periode se postavlja nova vrednost faktora ispunjenosti.
--! @image html generatorCetvrtki_state_diagram.png "Fig. 1. Masina stanja generatora cetvrtki"

architecture behav of generator_cetvrtki is
--! moguca stanja nasine masine stanja:
--sr:stanje reseta,s0:stanje logicke 0 na izlazu cetvrtke_out,s1:stanje log.jedinice na izlazu cetvrtke_out
type state_type is (sr,s0,s1);
--! trenutno i sledece stanje masine
signal state_reg,next_state: state_type;
signal counter: integer range 1 to 100:=1;--kontrolise izlaz u zavisnosti od duty cicle-a
--signal counter_clk sluzi za prilagodjavanje sistemskog takta Tclk=20ns nasim potrebama
signal counter_clk: integer range 0 to 19500:=0;--39*5,za plocu treba 39*500=19500
constant period_odbirka: integer:=19500;--19500
--period signala koji se dobija na izlazu DA konvertora
constant period: integer:=100;
--duty cicle uzima vrednosti od 0-100% u koracima od 10%
signal duty_cicle: integer range 0 to 100:=50;
signal napred_detekt,nazad_detekt: std_logic;


begin

--! Proces promene stanja. Kada je aktivan signal reseta, masina je u stanju sr.
state_transition: process(clk,reset) is
begin
	if (reset='1') then
		state_reg <= sr;
	elsif (rising_edge(clk)) then
		state_reg <= next_state;
	end if;
end process;

--! Proces odredjivanja sledeceg stanja. Promenljiva counter kontrolise raspodelu perioda u zavisnosti od faktora ispunjenosti. 
next_state_logic: process(state_reg,counter,duty_cicle,counter_clk) is
begin
	case(state_reg) is
		when sr =>
			next_state <= s1;  --iz reseta se prelazi u stanje log 1 koje traje 50% periode
		when s1 =>
			if(counter_clk=period_odbirka) then			
				if (counter=duty_cicle) then
					if(duty_cicle=100) then
						next_state <= s1;
					else
						next_state <= s0;
					end if;
				elsif(counter=100 and duty_cicle=0) then
					next_state <= s0;  --za slucaj kada se prelazi sa duty_cicle 100%->0%
				else
					next_state <= s1;
				end if;
			else
				next_state <= s1;
			end if;
		when s0 =>
			if(counter_clk=period_odbirka) then
				if (counter=100) then
					if(duty_cicle=0) then
						next_state <= s0;
					else
						next_state <= s1;
					end if;
				else
					next_state <= s0;
				end if;
			else
				next_state <= s0;
			end if;
	end case;
end process;

--! Proces generisanja izlaza. 
output_logic: process(state_reg) is
begin
	case(state_reg) is 
		when sr =>
			cetvrtke_out <= (others=>'0');
		when s1 =>								
			cetvrtke_out <= x"FFFF";
		when s0 =>
			cetvrtke_out <= x"0000";			
	end case;
end process;

--! Proces generisanja promenljive counter.  
counter_generator: process(clk,reset) is--ubacen counter_clk
begin
	if(reset='1') then
		counter <= 1;
	elsif (rising_edge(clk)) then
		if(counter_clk=period_odbirka) then
			if (counter=100) then
				counter <= 1;
			else
				counter <= counter+1;
			end if;
		end if;
	end if;
end process;

--! Proces generisanja brojaca koji sluzi za prilaodjavanje sistemskog signala takta nasoj komponenti.
counter_clk_generator: process(clk,reset) is
begin
	if(reset='1') then
		counter_clk <= 0;
	elsif (rising_edge(clk)) then
		if (counter_clk=period_odbirka) then
			counter_clk <= 1;
		else
			counter_clk <= counter_clk+1;
		end if;
	end if;
end process;

--! Proces generisanja faktora ispunjenosti.
duty_cicle_generator: process(clk,reset) is--ubacen counter_clk
begin
	if(reset='1') then
		duty_cicle <= 50;
	elsif (rising_edge(clk)) then
		if(counter_clk=period_odbirka-1) then--*****
			if(counter=100) then--*****
				if(napred_detekt='1') then
					if(duty_cicle=100) then
						duty_cicle <= 0;
					else
						duty_cicle <= duty_cicle+10;
					end if;
				elsif(nazad_detekt='1') then
					if(duty_cicle=0) then
						duty_cicle <= 100;
					else
						duty_cicle <= duty_cicle-10;
					end if;
				end if;
			end if;
		end if;
	end if;
end process;

--! Proces detektovanja prtisnutog tastera.
tasteri_detekt: process(clk,reset) is--ubacen counter_clk  
begin
	if(reset='1') then
		napred_detekt <= '0';
		nazad_detekt <= '0';
	elsif(rising_edge(clk)) then
		if(counter_clk=period_odbirka) then
			if(counter=100) then
				napred_detekt <= '0';
				nazad_detekt <='0';
			end if;
		end if;
		if(napred='1') then
			napred_detekt <= '1';
		elsif(nazad='1') then
			nazad_detekt <= '1';
		end if;
	end if;
end process;

end behav;