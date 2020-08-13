--! @file ulazni_reg.vhd
--! @brief Ulazni registar D/A konvertora
--! @details Ovaj fajl opisuje ulazni registar D/A konvertora. Fajl sadrzi opis interfejsa komponente i 
--! odgovarajuce arhitekture \n
--! @author Jelena Urosevic\n Stefan Vukasinovic

--! @date 12/12/2016
--! @version 1.0


library ieee;
use ieee.std_logic_1164.all;


--! @brief Deklaracija entitija za ulazni_reg
--! @details 
--! Ulazni registar je sekvencijalna komponenta koja za vreme aktivnog signala reseta, na izlazu postavlja nultu vrednost. Kada je signal reseta neaktivan, 
--! na 16-bitni izlaz postavlja se vrednost sa ulaza kada je aktivan signal load.

--! Interfejs ove komponente je prikazan na Fig. 1. \n
--! @image html ulazniReg.png "Fig. 1. Blok sema komponente ulazni_reg"

entity ulazni_reg is
port(
	--! ulazni odbirak
	reg_in: in std_logic_vector(15 downto 0);
	--! asinhroni reset
	clr: in std_logic; -- async. clear
	--! clk signal
	clk: in std_logic; -- clock
	--! load signal
	ld: in std_logic; -- load/enable
	--! izlazni odbirak
	reg_out: out std_logic_vector(15 downto 0)
);
end ulazni_reg;

architecture behav of ulazni_reg is

begin

process(clk, clr) is
begin
	if (clr = '1') then
		reg_out <= x"0000";
   elsif (rising_edge(clk)) then
      if (ld = '1') then
        reg_out <= reg_in;
      end if;
   end if;
end process;

end behav;