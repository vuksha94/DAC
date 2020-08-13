--! @file detektor.vhd
--! @brief Detektor
--! @details Ovaj fajl opisuje komponentu detektor. Fajl sadrzi opis interfejsa komponente i 
--! njegove arhitekture \n
--! @author Jelena Urosevic\n Stefan Vukasinovic
--! @date 12/12/2016
--! @version 1.0

library ieee;
use ieee.std_logic_1164.all;

--! @brief Deklaracija entitija za Detektor
--! @details 
--! Generise zahtev trajanja jednog Tclk, ukoliko je taster bio pritisnut
--! Blok simbol komonente je prikazan na Fig. 1.
--! @image html detektor.png "Fig. 1. Blok simbol komponente detektor"


entity detektor is

port(
	clk,reset: in std_logic;
    taster: in std_logic;
	zahtev: out std_logic
);
end detektor;

--! @brief opis arhitekture za detektor
--! @details
--! Ukoliko je ulazni signal taster na jedinici, masina prelazi u stanje u kojem se ukljucuje tajmer i broji do 
--! 1000000*Tclk. Potom masina prelazi u stanje u kojem proverava da li je signal taster i dalje na visokom nivou
--! i ukoliko jeste prelazi u stanje u kojem se generise izlazni signal zahtev trajanja jednog Tclk. 

architecture behav of detektor is

type state_type is (s1,s2,s3,s4,s5);
signal state_reg,next_state: state_type;
signal timer: integer range 0 to 1000000 :=0;
constant t_period: integer:=1000000; --postaviti na 1000000 za spustanje na plocu

begin

state_transition: process(clk,reset) is 
begin
	if(reset='1') then
		state_reg <= s1;
	elsif(rising_edge(clk)) then
		state_reg <= next_state;
	end if;
end process;

next_state_logic: process(state_reg,timer,taster) is
begin
	case(state_reg) is 
		when(s1) => 
			if (taster='0') then
				next_state <= s2;
			else
				next_state <= s1;
			end if;
		when(s2) => 
			if (timer=t_period) then
				next_state <= s3;
			else
				next_state <= s2;
			end if;
		when(s3) =>
			if (taster='0') then	
				next_state <= s4;
			else 
				next_state <= s1;
			end if;
		when(s4) =>
			next_state <= s5;

		when(s5) => 
			if (taster='1') then
				next_state <= s1;
			else
				next_state <= s5;
			end if;
	end case;
end process;

output_logic: process(state_reg) is
begin
	case(state_reg) is
		when (s1) =>
			zahtev <= '0';
		when(s2) =>
			zahtev <= '0';
		when(s3) =>
			zahtev <= '0';
		when(s4) =>
			zahtev <= '1';
		when(s5) =>
			zahtev <= '0';
	end case;
end process;

timer_generator: process(clk,reset) is
begin
		if (reset = '1') then
			timer <= 0;
		elsif (clk'event and clk = '1') then
			if(state_reg=s2) then
				if (timer=t_period) then
					timer <= 1;
				else
					timer <= timer + 1;
				end if;
			else	
				timer <= 0;
			end if;
		end if;
end process;

end behav;