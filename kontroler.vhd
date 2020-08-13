--! @file kontroler.vhd
--! @brief Kontroler koji izvrsava komunikaciju sa plocicom D/A konvertora.
--! @details Ovaj fajl opisuje kontroler. Fajl sadrzi opis interfejsa komponente i odgovarajuce arhitekture \n
--! Potrebni vremenski dijagrami su prikazani na fig.1 i 2. Dobijeni vremenski dijagram prikazan je na fig.3.
--! @author Jelena Urosevic\n Stefan Vukasinovic
--! @date 12/12/2016
--! @version 1.0
--! @image html kontrolertiming_diagram.png "Fig. 1. Vremenski dijagram - trazeni oblik signala SDA i SCL "\n
--! @image html LTC2607_timingcharateristics.png "Fig. 2. Vremenske karakteristike "\n
--! @image html DAK_generatorSignalatiming_diagram.png "Fig. 3. Vremenski dijagram - SDA i SCL za SA[6..0]=0010000 i CA[7..0]=00110000 i 16-bitni odbirak sa vrednoscu 0"\n


library ieee;
use ieee.std_logic_1164.all;


--! @brief Deklaracija entitija za kontroler
--! @details 
--! Kontroler je sekvencijalna komponenta koja ostvaruje komunikaciju izmedju modula generator_signala
--! i LTC2607 plocice D/A konvertora sa I2C protokolom. Kontroler prihvata odbirke koji su poslati sa 
--! generatora signala i generise izlazne signale SCL i SDA tako da zadovolje definisani protokol.
--! Kada je D/A konvertor spreman da prihvati naredni odbirak, kontroler aktivira signal load_data i
--! oznacava da je spreman da prihvati 16-bitni podatak.
--! Interfejs ove komponente je prikazan na Fig. 1. \n
--! @image html kontroler.png "Fig. 1. Blok simbol komponente kontroler"

entity kontroler is
port(
	-- Input ports
	clk,reset: in std_logic;	
	--! ulazni podatak - odbirak
	data_in: in std_logic_vector(15 downto 0);
	--! ulazno izlazni signal - preko njega se salju podaci
	SDA	: out std_logic;
	--! izlazni signal - signal takta za plocicu LTC2607
	SCL	: out std_logic;
	--! izlazni signal 
	load_data: out std_logic --vodi se na enable ulaznog REG
);
end kontroler;

--! @brief Opis arhitekture za kontroler
--! @details
--! Kontroler je realizovan iz dve kompleksne masine stanja, po jedna za svaki od izlanih signala SCL i SDA.
--! Ove masine stanja imaju onoliko stanja koliko je potrebno da se ispostuje I2C protokol kao i komunikacija
--! sa LTC2607 plocicom. Masin stanja koja generise izlaz SDA je mnogo kompleksnija i sastoji se od 11 stanja
--! kojima su obuhvaceni svi potrebni protokoli kako bi odbirak koji se salje na ulaz D/A konvertora bio ispravno
--! upisan. Masina stanja koja generise izlaz SCL ima samo 4 stanja. Na fig. 1.i 2. su prikazane masine stanja
--! za SCL i za SDA na kojoj su oznaceni bitni signali koji dovode do promene stanja
--! @image html kontrolerSCL_state_diagram.png "Fig. 1. masina stanja za SDA"
--! @image html kontrolerSDA_state_diagram.png "Fig. 2. masina stanja za SCL"

architecture behav of kontroler is
--odbirak koji se salje na ulaz DA konvertora predstavljen visim i nizim bajtom
signal data_high: std_logic_vector(7 downto 0):= x"00";
signal data_low: std_logic_vector(7 downto 0):= x"00";

constant slave_address: std_logic_vector(6 downto 0):="0010000";--slave address
constant first_data_byte: std_logic_vector(7 downto 0):="00110000";--chip select
--konstantne vrednosti kasnjenja koje se koriste za transformaciju 50MHz->100KHz
constant t1: integer range 0 to 500 := 15;-- 0<Thd(dat)<0.9us treba da bude 15 sto je 0.3us
constant t3: integer range 0 to 500 := 300;--vreme trajanja niskog nivoa signala SCL ->300 sto je 6us
constant t4: integer range 0 to 500 := 400;--4/5 periode ->400
constant tperiod: integer:= 500;--period treba da bude 500 sto je 10us

signal counter: integer range 0 to 500:=0;  --sluzi za prilagodjavanje signala takta,treba nam f=100kHz
signal counter_slave: integer range 0 to 6:=6;--odredjuje index bita slave adrese koji se propusta na izlaz SDA
signal counter_1data_byte: integer range 0 to 7:=7;--odredjuje index bita first_data_byte koji se propusta na izlaz SDA
signal counter_2data_byte: integer range 0 to 7:=7;--odredjuje index bita data_high koji se propusta na izlaz SDA
signal counter_3data_byte: integer range 0 to 7:=7;--odredjuje index bita data_low koji se propusta na izlaz SDA
--stanja dve masine stanja koje odredjuju izlaze SDA i SCL
type state_type_SDA is(a_reset, a_start1, a_start0, a_slave, a_write, a_ack, a_1d, a_2d, a_3d, a_kraj, a_stop);
type state_type_SCL is(b_reset, b_start, b0, b1);
signal state_reg_SDA, next_state_SDA: state_type_SDA;
signal state_reg_SCL, next_state_SCL: state_type_SCL;

begin
--! Proces promene stanja za SDA.
state_transition_SDA: process(clk, reset) is
begin
	if (reset='1') then
		state_reg_SDA <= a_reset;
	elsif (rising_edge(clk)) then
		state_reg_SDA <= next_state_SDA;
	end if;
end process;

--! Proces promene stanja za SCL.
state_transition_SCL: process(clk, reset) is
begin
	if (reset='1') then
		state_reg_SCL <= b_reset;
	elsif (rising_edge(clk)) then
		state_reg_SCL <= next_state_SCL;
	end if;
end process;

--! Proces odredjivanja sledeceg stanja SDA.
next_state_logic_SDA: process(state_reg_SDA, counter, counter_slave, counter_1data_byte, counter_2data_byte, counter_3data_byte) is
begin
	case(state_reg_SDA) is
		when a_reset =>
			next_state_SDA <= a_start1;
		when a_start1 =>
			if(counter=t4) then --ovede su 4/5 perioda a treba da bude 400 jer su to 4/5 od 500
				next_state_SDA <= a_start0;
			else
				next_state_SDA <= a_start1;
			end if;
		when a_start0 =>  --ovde treba pitati da li je counter=500 ali ga treba i zakasniti za
			if(counter=t1) then-- 0.3us sto je 15.Ovde cemo ga zakasniti za 1
				next_state_SDA <= a_slave;
			else
				next_state_SDA <= a_start0;
			end if;
		when a_slave =>
			if(counter_slave=0 and counter=t1) then -- treba da bude counter=15 jer je to 0.3us
				next_state_SDA <= a_write;      --prelazi se u stanje a_write kada se prosledi i 
			else										  -- poslednji bit slave_adrese
				next_state_SDA <= a_slave;
			end if;
		when a_write =>
			if(counter=t1) then  -- 0.3us sto je 15.Ovde cemo ga zakasniti za 1
				next_state_SDA <= a_ack;
			else
				next_state_SDA <= a_write;
			end if;
      --u ovom stanju je SDA pin ulazni i potrebno je postaviti na njegov izlaz visoku impedansu 
		when a_ack =>    --kako bi slave mog0 da postavi ACK=0. U slucaju potrebe za komunikacijom
								--sa slejvom ovde bi bilo potrbe za dodatnim signalom ack koji bi nosio inf. da 
								--li je slejv za vreme ovog stanja postavio log.0 na izlaz
			if(counter=t1) then  -- 0.3us sto je 15.Ovde cemo ga zakasniti za 1 
				if(counter_3data_byte=0) then--provera da li je zavrsen ciklus upisa 3rdDataByte na SDA
					next_state_SDA <= a_kraj;
				elsif(counter_2data_byte=0) then--provera da li je zavrsen ciklus upisa 2ndDataByte na SDA
					next_state_SDA <= a_3d;
				elsif(counter_1data_byte=0) then--provera da li je zavrsen ciklus upisa 1stDataByte na SDA
					next_state_SDA <= a_2d;
				else --ako nije znaci da je tek upisana slave adresa
					next_state_SDA <= a_1d;
				end if;	
			else
				next_state_SDA <= a_ack;
			end if;
			
		when a_1d =>
			if(counter_1data_byte=0 and counter=t1) then
				next_state_SDA <= a_ack;
			else
				next_state_SDA <= a_1d;
			end if;
		when a_2d =>
			if(counter_2data_byte=0 and counter=t1) then
				next_state_SDA <= a_ack;
			else
				next_state_SDA <= a_2d;
			end if;
		when a_3d =>
			if(counter_3data_byte=0 and counter=t1) then
				next_state_SDA <= a_ack;
			else
				next_state_SDA <= a_3d;
			end if;
			
		when a_kraj =>
			if(counter=tperiod) then
				next_state_SDA <= a_stop;
			else
				next_state_SDA <= a_kraj;
			end if;
		when a_stop =>
			if(counter=tperiod) then
				next_state_SDA <= a_start1;
			else
				next_state_SDA <= a_stop;
			end if;			
	end case;

end process;

--! Proces odredjivanja sledeceg stanja SCL.
next_state_logic_SCL: process(state_reg_SCL, state_reg_SDA, counter) is
begin
	case(state_reg_SCL) is
		when b_reset =>
			next_state_SCL <= b_start;
		when b_start =>
			if(counter=tperiod) then   --500
				next_state_SCL <= b0;
			else
				next_state_SCL <= b_start;
			end if;
		when b0 =>
			if(counter=t3) then  --300
				next_state_SCL <= b1;
			else
				next_state_SCL <= b0;
			end if;
		when b1 =>			
			if(counter=tperiod) then 	--500
				if(state_reg_SDA=a_stop) then--provera da li je kraj ciklusa
					next_state_SCL <= b_start;
				else
					next_state_SCL <= b0;
				end if;
			else
				next_state_SCL <= b1;
			end if;
	end case;

end process;

--! Izlazna logika SDA. Izlaz zavisi od trenutnog stanja.
output_logic_SDA: process(state_reg_SDA, counter_slave, counter_1data_byte, counter_2data_byte, counter_3data_byte, data_high, data_low) is
begin
	case(state_reg_SDA) is
		when a_reset =>
			SDA <= '1';
			load_data <= '0';
		when a_start1 =>
			SDA <= '1';
			load_data <= '0';
		when a_start0 =>
			SDA <= '0';
			load_data <= '1';				
		when a_slave =>
			SDA <= slave_address(counter_slave);
			load_data <= '0';
		when a_write =>
			SDA <= '0';
			load_data <= '0';
		when a_ack =>
			SDA <= 'Z';
			load_data <= '0';
		when a_1d =>
			SDA <= first_data_byte(counter_1data_byte);
			load_data <= '0';
		when a_2d =>
			SDA <= data_high(counter_2data_byte);
			load_data <= '0';
		when a_3d =>
			SDA <= data_low(counter_3data_byte);
			load_data <= '0';
		when a_kraj =>
			SDA <= '0';
			load_data <= '0';
		when a_stop =>
			SDA <= '0';	
			load_data <= '0';		
	end case;
end process;

--! Izlazna logika SCL. Izlaz zavisi od trenutnog stanja.
output_logic_SCL: process(state_reg_SCL) is
begin
	case(state_reg_SCL) is
		when b_reset =>
			SCL <= '1';
		when b_start =>
			SCL <= '1';
		when b0 =>
			SCL <= '0';
		when b1 =>
			SCL <= '1';
	end case;
end process;

--! Proces generisanja promenljive counter koja sluzi za podesavanje vremena trajanja stanja
counter_generator: process(clk,reset) is
begin
	if (reset='1') then 
		counter <= 0;
	elsif(rising_edge(clk)) then
		if(counter=tperiod) then   --treba promenii na 500 da bi bila perioda 10us 
			counter <=1;    
		else
			counter <= counter + 1;
		end if;
	end if;
end process;

--! Proces generisanja promenljive counter_slave_generator. Odredjuje bit slave_address koji se prosledjuje na izlaz SDA
counter_slave_generator: process(clk, reset, state_reg_SDA, counter) is
begin
	if (reset='1') then 
		counter_slave <= 6;
	elsif(rising_edge(clk)) then
		case (state_reg_SDA) is	
			when a_slave =>   -- ako je stanje upisivanja slave adrese
				if(counter=t1) then --treba da bude 15,posle 0.3us.
					if(counter_slave>0) then --ako je counter_slave=0 ne treba ga smanjiti na -1
						counter_slave <= counter_slave - 1; 
					end if;	
				end if;
			when a_kraj =>
				counter_slave <= 6;
			when others =>   --ostavljamo ga na 0 tokom celog ciklusa kako bi njegova vrednost 
				null;--signalizirala stanju a_ack gde se nalazi i koje je sledece stanje 
		end case;
	end if;
end process;

--! Proces generisanja promenljive counter_1data_byte_generator. Odredjuje bit prvog bajta podatka 
--! u okviru prenosa koji se prosledjuje na izlaz SDA. U ovih 8 bita su sadrzani komanda i adresa 
--! potrebni za pravilno ukljucenje D/A konvertora
counter_1data_byte_generator: process(clk, reset, state_reg_SDA, counter) is
begin
	if (reset='1') then 
		counter_1data_byte <= 7;
	elsif(rising_edge(clk)) then
		case (state_reg_SDA) is
			when a_1d =>
				if(counter=t1) then --treba da bude 15,posle 0.3us.
					if(counter_1data_byte > 0) then --ako je counter_1data_byte=0 ne treba ga smanjiti na -1
						counter_1data_byte <= counter_1data_byte - 1; 
					end if;	
				end if;
			when a_kraj =>
				counter_1data_byte <= 7;
			when others =>   --ostavljamo ga na 0 tokom celog ciklusa kako bi njegova vrednost 
				null;         --signalizirala stanju a_ack gde se nalazi i koje je sledece stanje 
		end case;
	end if;
end process;

--! Proces generisanja promenljive counter_2data_byte_generator. Odredjuje bit u okviru prvog bajta odbirka
--! koji se prosledjuje na izlaz SDA.
counter_2data_byte_generator: process(clk, reset, state_reg_SDA, counter) is
begin
	if (reset='1') then 
		counter_2data_byte <= 7;
	elsif(rising_edge(clk)) then
		case (state_reg_SDA) is
			when a_2d =>
				if(counter=t1) then --treba da bude 15,posle 0.3us.
					if(counter_2data_byte > 0) then --ako je counter_2data_byte=0 ne treba ga smanjiti na -1
						counter_2data_byte <= counter_2data_byte - 1; 
					end if;	
				end if;
			when a_kraj =>
				counter_2data_byte <= 7;
			when others =>   --ostavljamo ga na 0 tokom celog ciklusa kako bi njegova vrednost 
				null;         --signalizirala stanju a_ack gde se nalazi i koje je sledece stanje 
		end case;
	end if;
end process;

--! Proces generisanja promenljive counter_3data_byte_generator. Odredjuje bit u okviru drugog bajta odbirka
--! koji se prosledjuje na izlaz SDA.
counter_3data_byte_generator: process(clk, reset, state_reg_SDA, counter) is
begin
	if (reset='1') then 
		counter_3data_byte <= 7;
	elsif(rising_edge(clk)) then
		case (state_reg_SDA) is
			when a_3d =>
				if(counter=t1) then --treba da bude 15,posle 0.3us.
					if(counter_3data_byte > 0) then --ako je counter_3data_byte=0 ne treba ga smanjiti na -1
						counter_3data_byte <= counter_3data_byte - 1; 
					end if;	
				end if;
			when a_kraj =>
				counter_3data_byte <= 7;
			when others =>   --ostavljamo ga na 0 tokom celog ciklusa kako bi njegova vrednost 
				null;         --signalizirala stanju a_ack gde se nalazi i koje je sledece stanje 
		end case;
	end if;
end process;

data_high <= data_in(15 downto 8);
data_low <= data_in(7 downto 0);

end behav;