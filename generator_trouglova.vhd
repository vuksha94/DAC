--! @file generator_trouglova.vhd
--! @brief Generator trougaonog signala
--! @details Ovaj fajl opisuje generator trougaonog signala. Fajl sadrzi opis interfejsa komponente i 
--! odgovarajuce arhitekture \n
--! @author Jelena Urosevic\n Stefan Vukasinovic
--! @date 12/12/2016
--! @version 1.0


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief Deklaracija entitija za generator_trouglova
--! @details 
--! Generator trouglova je sekvencijalna komponenta koja generise 16-bitni izlaz, 
--! koji predstavlja odbirak koji se preko multipleksera salje na ulaz D/A konvertora.
--! Faktor ispunjenosti signala na izlazu D/A konvertora se moze podesavati pomocu tastera napred i nazad
--! u koracima od po 10%. 
--! Interfejs ove komponente je prikazan na Fig. 1. \n
--! @image html generatorTrouglova.png "Fig. 1. Blok simbol komponente generator_trouglova"

entity generator_trouglova is
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
end generator_trouglova;

--! @brief opis arhitekture za generator_trouglova
--! @details
--! Generator trouglova je realizovan kao masina stanja prikazana na Fig. 1. Masina ima tri stanja: <b>sr</b>, <b>s0</b>
--! i <b>s1</b>. Stanje <b>sr</b> predstavlja stanje reseta. Po ukidanju signala reseta, masina prelazi u stanje <b>s1</b>
--! u kojem ostaje 50% perioda (faktor ispunjenosti je 50%). U stanju <b>s1</b>, izlaz se inkrementira na uzlaznu ivicu signala takta, 
--! koja je skalirana tako da zadovolji frekvenciju odabiranja D/A konvertora. Konstantni korak inkrementiranja je odredjen faktorom ispunjenosti.
--! Ostatak perioda masina se nalazi u stanju <b>s0</b> u kojem se izlaz dekrementira na isti nacin kao sto se vrsi inkrementiranje u stanju <b>s1</b>.
--! Ukoliko je u toku perioda pritisnut taster napred ili nazad, taj dogadjaj se pamti u posebnoj promenljivoj,
--! i na kraju periode se postavlja nova vrednost faktora ispunjenosti.
--! @image html generatorTrouglova_state_diagram.png "Fig. 1. Masina stanja generatora trouglova"

architecture behav of generator_trouglova is

--! moguca stanja nasine masine stanja:
type state_type is (sr,s0,s1);
--! trenutno i sledece stanje masine
signal state_reg,next_state: state_type;
signal counter: integer range 1 to 100:=1;
--signal counter_clk sluzi za prilagodjavanje sistemskog takta Tclk=20ns nasim potrebama
signal counter_clk: integer range 0 to 19500:=0;--39*5,za plocu treba 39*500=19500
constant period_odbirka: integer:=19500;--19500
signal duty_cicle: integer range 0 to 100:=50;--duty cicle uzima vrednosti od 0-100% u koracima od 10%
--promenljiva u kojoj se cuva trenutna vrednost izlaza koji se vodi na truglovi_out[15..0]
signal trenutna_vrednost:integer range 0 to 65535:=0;
--koraci za generisanje trougla u zavisnosti od duzine trajanja duty_cicle
constant korak_10: integer:=7282; --round(65535/9)
constant korak_90: integer:=737;
constant korak_20: integer:=3450;
constant korak_80: integer:=830;
constant korak_30: integer:=2260;
constant korak_70: integer:=950;
constant korak_40: integer:=1681;
constant korak_60: integer:=1111;
constant korak_50: integer:=1338;
constant korak_100: integer:=662; --isti korak se koristi za duty_cicle=0%
--signali koji pamte da li je pritisnut taster napred ili nazad
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
					if(duty_cicle=100) then -- ako je duty_cicle=100% ostaje se u s1
						next_state <= s1;
					else
						next_state <= s0;
					end if;
				elsif(counter=100 and duty_cicle=0) then
					next_state <= s0;  --za slucaj kada se prelazi sa duty_cicle 100->0%
				else
					next_state <= s1;
				end if;
			else
				next_state <= s1;
			end if;
		when s0 =>
			if(counter_clk=period_odbirka) then
				if (counter=100) then
					if(duty_cicle=0) then --  ako je duty_cicle=0 ostaje se u s0  
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
output_logic: process(state_reg,trenutna_vrednost) is
begin
	case(state_reg) is 
		when sr =>
			truglovi_out <= (others=>'0');
		when others =>
			--postavlja na izlaz truglovi_out[15..0] vrednost promenljive trenutna_vrednost(integer) 
			truglovi_out <= std_logic_vector(to_unsigned(trenutna_vrednost,16));
	end case;
end process;

--! Proces generisanja promenljive counter. 
counter_generator: process(clk,reset) is--ubacen counter_clk
begin
	if(reset='1') then
		counter <= 1; --**********
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

--! Proces generisanja brojaca koji sluzi za prilagodjavanje sistemskog signala takta nasoj komponenti.
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


--! Proces generisanja promenljive koja odredjuje trenutnu vrednost izlaza
trenutna_vrednost_generator: process(clk,reset) is--ubacen counter_clk -- obrisani iz sens.list:duty_cicle,state_reg
begin
	if(reset='1') then
		trenutna_vrednost <= 0;
	elsif(rising_edge(clk)) then
		if(counter_clk=period_odbirka) then
			case(duty_cicle) is
				when 0 =>
					if(state_reg=s1) then --samo pri prelasku sa duty_cicle sa 100%->0% 
						trenutna_vrednost <= 65535;--da bi zadrzali vr. 65535 2*Tclk
					else
						if(trenutna_vrednost=0) then 
							trenutna_vrednost <= 65535;
						elsif(trenutna_vrednost - korak_100 > 0) then
							trenutna_vrednost <= trenutna_vrednost - korak_100;
						else
							trenutna_vrednost <= 0;
						end if;
					end if;
				when 10 =>
					if(state_reg=s1) then       
						if(next_state=s0) then        --sa ovim delom drzimo max vrednost na izlazu 2*Tclk pri
							trenutna_vrednost <= 65535;--prelazu sa state_reg=s1 -> state_reg=s0
						elsif(trenutna_vrednost + korak_10 < 65535) then
							trenutna_vrednost <= trenutna_vrednost + korak_10;
						else
							trenutna_vrednost <= 65535;
						end if;
					elsif(state_reg=s0) then   
						if(next_state=s1) then --sa ovim delom drzimo min vrednost na izlazu 2*Tclk pri
							trenutna_vrednost <= 0;--prelazu sa state_reg=s0 -> state_reg=s1
						elsif(trenutna_vrednost - korak_90 > 0) then
							trenutna_vrednost <= trenutna_vrednost - korak_90;
						else
							trenutna_vrednost <= 0;
						end if;
					end if;
				when 20 =>
					if(state_reg=s1) then 
						if(next_state=s0) then  --zbog prelaskasa s1->s0 da ne bi bilo kasnjenja
							trenutna_vrednost <= 65535;
						elsif(trenutna_vrednost + korak_20 < 65535) then
							trenutna_vrednost <= trenutna_vrednost + korak_20;
						else
							trenutna_vrednost <= 65535;
						end if;
					elsif(state_reg=s0) then
						if(next_state=s1) then --zbog prelaskasa s0->s1 da ne bi bilo kasnjenja
							trenutna_vrednost <= 0;
						elsif(trenutna_vrednost - korak_80 > 0) then
							trenutna_vrednost <= trenutna_vrednost - korak_80;
						else
							trenutna_vrednost <= 0;
						end if;
					end if;
				when 30 =>
					if(state_reg=s1) then 
						if(next_state=s0) then  --zbog prelaskasa s1->s0 da ne bi bilo kasnjenja
							trenutna_vrednost <= 65535;
						elsif(trenutna_vrednost + korak_30 < 65535) then
							trenutna_vrednost <= trenutna_vrednost + korak_30;
						else
							trenutna_vrednost <= 65535;
						end if;
					elsif(state_reg=s0) then
						if(next_state=s1) then --zbog prelaskasa s0->s1 da ne bi bilo kasnjenja
							trenutna_vrednost <= 0;
						elsif(trenutna_vrednost - korak_70 > 0) then
							trenutna_vrednost <= trenutna_vrednost - korak_70;
						else
							trenutna_vrednost <= 0;
						end if;
					end if;
				when 40 =>
					if(state_reg=s1) then 
						if(next_state=s0) then  --zbog prelaskasa s1->s0 da ne bi bilo kasnjenja
							trenutna_vrednost <= 65535;
						elsif(trenutna_vrednost + korak_40 < 65535) then
							trenutna_vrednost <= trenutna_vrednost + korak_40;
						else
							trenutna_vrednost <= 65535;
						end if;
					elsif(state_reg=s0) then
						if(next_state=s1) then --zbog prelaskasa s0->s1 da ne bi bilo kasnjenja
							trenutna_vrednost <= 0;
						elsif(trenutna_vrednost - korak_60 > 0) then
							trenutna_vrednost <= trenutna_vrednost - korak_60;
						else
							trenutna_vrednost <= 0;
						end if;
					end if;
				when 50 =>
					if(state_reg=s1) then 
						if(next_state=s0) then  --zbog prelaskasa s1->s0 da ne bi bilo kasnjenja
							trenutna_vrednost <= 65535;
						elsif(trenutna_vrednost + korak_50 < 65535) then
							trenutna_vrednost <= trenutna_vrednost + korak_50;
						else
							trenutna_vrednost <= 65535;
						end if;
					elsif(state_reg=s0) then
						if(next_state=s1) then --zbog prelaskasa s0->s1 da ne bi bilo kasnjenja
							trenutna_vrednost <= 0;
						elsif(trenutna_vrednost - korak_50 > 0) then
							trenutna_vrednost <= trenutna_vrednost - korak_50;
						else
							trenutna_vrednost <= 0;
						end if;
					end if;
				when 60 =>
					if(state_reg=s1) then
						if(next_state=s0) then  --zbog prelaskasa s1->s0 da ne bi bilo kasnjenja
							trenutna_vrednost <= 65535;
						elsif(trenutna_vrednost + korak_60 < 65535) then
							trenutna_vrednost <= trenutna_vrednost + korak_60;
						else
							trenutna_vrednost <= 65535;
						end if;
					elsif(state_reg=s0) then
						if(next_state=s1) then --zbog prelaskasa s0->s1 da ne bi bilo kasnjenja
							trenutna_vrednost <= 0;
						elsif(trenutna_vrednost - korak_40 > 0) then
							trenutna_vrednost <= trenutna_vrednost - korak_40;
						else
							trenutna_vrednost <= 0;
						end if;
					end if;	
				when 70 =>
					if(state_reg=s1) then 
						if(next_state=s0) then  --zbog prelaskasa s1->s0 da ne bi bilo kasnjenja
							trenutna_vrednost <= 65535;
						elsif(trenutna_vrednost + korak_70 < 65535) then
							trenutna_vrednost <= trenutna_vrednost + korak_70;
						else
							trenutna_vrednost <= 65535;
						end if;
					elsif(state_reg=s0) then
						if(next_state=s1) then --zbog prelaskasa s0->s1 da ne bi bilo kasnjenja
							trenutna_vrednost <= 0;
						elsif(trenutna_vrednost - korak_30 > 0) then
							trenutna_vrednost <= trenutna_vrednost - korak_30;
						else
							trenutna_vrednost <= 0;
						end if;
					end if;
				when 80 =>
					if(state_reg=s1) then 
						if(next_state=s0) then  --zbog prelaskasa s1->s0 da ne bi bilo kasnjenja
							trenutna_vrednost <= 65535;
						elsif(trenutna_vrednost + korak_80 < 65535) then
							trenutna_vrednost <= trenutna_vrednost + korak_80;
						else
							trenutna_vrednost <= 65535;
						end if;
					elsif(state_reg=s0) then
						if(next_state=s1) then --zbog prelaskasa s0->s1 da ne bi bilo kasnjenja
							trenutna_vrednost <= 0;
						elsif(trenutna_vrednost - korak_20 > 0) then
							trenutna_vrednost <= trenutna_vrednost - korak_20;
						else
							trenutna_vrednost <= 0;
						end if;
					end if;
				when 90 =>
					if(state_reg=s1) then 					
						if(next_state=s0) then  --zbog prelaskasa s1->s0 da ne bi bilo kasnjenja
							trenutna_vrednost <= 65535;
						elsif(trenutna_vrednost=65535) then --kada duty_cicle prelazi sa 100->90% potrebno je 
							trenutna_vrednost <= 0;			--upisati 0 na izlaz
						elsif(trenutna_vrednost + korak_90 < 65535) then
							trenutna_vrednost <= trenutna_vrednost + korak_90;
						else
							trenutna_vrednost <= 65535;
						end if;
					elsif(state_reg=s0) then
						if(next_state=s1) then --zbog prelaskasa s0->s1 da ne bi bilo kasnjenja
							trenutna_vrednost <= 0;
						elsif(trenutna_vrednost - korak_10 > 0) then
							trenutna_vrednost <= trenutna_vrednost - korak_10;
						else
							trenutna_vrednost <= 0;
						end if;
					end if;
				when 100 =>
					if(state_reg=s0) then --samo pri prelasku sa duty_cicle sa 90->100% 
						trenutna_vrednost <= 0;
					else
						if(trenutna_vrednost=65535) then  
							trenutna_vrednost <= 0;
						elsif(trenutna_vrednost + korak_100 < 65535) then
							trenutna_vrednost <= trenutna_vrednost + korak_100;
						else
							trenutna_vrednost <= 65535;
						end if;
					end if;
				when others =>
					null;
			end case;
		end if;
	end if;
end process;

--! Proces generisanja faktora ispunjenosti.
duty_cicle_generator: process(clk,reset) is--ubacen counter_clk
begin
	if(reset='1') then
		duty_cicle <= 50;
	elsif (rising_edge(clk)) then
		if(counter_clk=period_odbirka-1) then
			if(counter=100) then
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

--Kada je taster pritisnut,potrebno je zapamtiti tu informaciju da bi na kraju perioda 
--bio promenjen duty cicle
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