-- cpu.vhd: Simple 8-bit CPU (BrainLove interpreter)
-- Copyright (C) 2021 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Matus Justik (xjusti00)
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_WREN  : out std_logic;                    -- cteni z pameti (DATA_WREN='0') / zapis do pameti (DATA_WREN='1')
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna pokud IN_VLD='1'
   IN_REQ    : out std_logic;                     -- pozadavek na vstup dat z klavesnice
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat,  OUT_WREN musi byt '0'
   OUT_WREN : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

signal pc_reg_addr:	std_logic_vector(11 downto 0);
signal pc_reg_inc :	std_logic;
signal pc_reg_dec : std_logic;

signal ptr_reg_addr: std_logic_vector(9 downto 0);
signal ptr_reg_inc : std_logic;
signal ptr_reg_dec : std_logic;

signal cnt_reg_addr : std_logic_vector(7 downto 0);
signal cnt_reg_inc : std_logic;
signal cnt_reg_dec : std_logic;

signal mx_sel: std_logic_vector(1 downto 0);
signal mx_inc: std_logic_vector(7 downto 0); 
signal mx_dec: std_logic_vector(7 downto 0); 

signal por_cnt: std_logic;
signal por_dar: std_logic;

--    stavy
type fsm_state is (
          s_start,
          s_fetch,
          s_decode,

          s_ptr_dec,
          s_ptr_inc,

          s_val_dec, help_s_val_dec,
          s_val_inc, help_s_val_inc,

          s_while_start, help_s_while_start, helpp_s_while_start, helppp_s_while_start, helpppp_s_while_start, helppppp_s_while_start,
          s_while_end, help_s_while_end, helpp_s_while_end, helppp_s_while_end, helpppp_s_while_end, helppppp_s_while_end, helpppppp_s_while_end, helppppppp_s_while_end,

          s_output,
          s_input,

          s_null

      
);


signal fsm_signal: fsm_state := s_start;


--		Samotne komponenty

begin

--		Register PC

pc: process(CLK, RESET)
begin
	
if(RESET = '1') then
		  pc_reg_addr <= "000000000000";
elsif(CLK'event and CLK = '1') then
	if(pc_reg_inc = '1') then
	  	pc_reg_addr <= pc_reg_addr + 1;
  elsif(pc_reg_dec = '1') then
		  pc_reg_addr <= pc_reg_addr - 1;
	end if;
end if;

CODE_ADDR <= pc_reg_addr;
end process;

--		Register PTR -----------------------------------------------v

ptr: process(CLK, RESET)
begin

if(RESET = '1') then
	ptr_reg_addr <= "0000000000";
elsif(CLK'event and CLK = '1') then
	if(ptr_reg_inc = '1') then
		ptr_reg_addr <= ptr_reg_addr + 1;
	elsif(ptr_reg_dec = '1') then
		ptr_reg_addr <= ptr_reg_addr - 1;
	end if;
end if;

DATA_ADDR <= ptr_reg_addr;
end process;

--		Register CNT -----------------------------------------------

cnt: process(CLK, RESET)
begin 
	
if(RESET = '1') then
	cnt_reg_addr <= "00000000";
elsif(CLK'event and CLK = '1') then
	if(cnt_reg_inc = '1') then
		cnt_reg_addr <= cnt_reg_addr + 1;
	elsif(cnt_reg_dec = '1') then
		cnt_reg_addr <= cnt_reg_addr - 1;
	end if;
end if;	

end process;

-----------------------------------------------

mx_inc_komp: process(DATA_RDATA)
begin
    mx_inc <= DATA_RDATA +1;
end process;


mx_dec_komp: process(DATA_RDATA)
begin
    mx_dec <= DATA_RDATA -1;
end process;


por_cnt_komp: process(cnt_reg_addr)
begin
    if cnt_reg_addr = "00000000" then
      por_cnt <= '1';
    else
      por_cnt <= '0';
    end if ;
end process;


por_dar_komp: process(DATA_RDATA)
begin
    if DATA_RDATA = "00000000" then
      por_dar <= '1';
    else
      por_dar <= '0';
    end if ;
end process;

-----------------------------------------------

mx: process(IN_DATA, DATA_RDATA, mx_sel, mx_inc, mx_dec)
	begin
		case(mx_sel) is
			when "00" => DATA_WDATA <= IN_DATA;
			when "01" => DATA_WDATA <= mx_inc;
			when "10" => DATA_WDATA <= mx_dec;
			when "11" => DATA_WDATA <= DATA_RDATA;
			when others =>
		end case;
	end process;
-----------------------------------------------

fsm: process(CLK, RESET)

begin

if RESET = '1' then
  fsm_signal <= s_start;
  pc_reg_inc <= '0';
  pc_reg_dec <= '0';
  ptr_reg_inc <= '0';
  ptr_reg_dec <= '0';
  cnt_reg_inc <= '0';
  cnt_reg_dec <= '0';
  CODE_EN <= '0';
  DATA_EN <= '0';
  DATA_WREN <= '0';
  OUT_WREN <= '0';
  mx_sel <= "00";

elsif rising_edge(CLK) and EN = '1' then
    OUT_DATA <= DATA_RDATA;
    case fsm_signal is
              when s_start =>
                          CODE_EN <= '1';
                          pc_reg_inc <= '1';
                          fsm_signal <= s_fetch;
              when  s_fetch =>
                          CODE_EN <= '0';
                          pc_reg_inc <= '0';
                          fsm_signal <= s_decode;
              when s_decode =>
                          case CODE_DATA is 
                                  when x"3E" => 
                                    ptr_reg_inc <= '1';
                                    fsm_signal <= s_ptr_inc;
                                  when x"3C" => 
                                    ptr_reg_dec <= '1';
                                    fsm_signal <= s_ptr_dec;
                                  when x"2B" => 
                                    DATA_WREN <= '0';
                                    DATA_EN <= '1';
                                    fsm_signal <= s_val_inc;
                                  when x"2D" => 
                                    DATA_WREN <= '0';
                                    DATA_EN <= '1';
                                    fsm_signal <= s_val_dec;
                                  when x"5B" => 
                                    DATA_WREN <= '0';
                                    DATA_EN <= '1';
                                    fsm_signal <= s_while_start;
                                  when x"5D" => 
                                    DATA_WREN <= '0';
                                    DATA_EN <= '1';  
                                    fsm_signal <= helppppp_s_while_end;
                                  when x"2E" => 
                                   DATA_WREN <= '0';
                                   DATA_EN <= '1';
                                   if OUT_BUSY = '0' then
                                    OUT_WREN <= '1';
                                    fsm_signal <= s_output;
                                  end if;
                                  when x"2C" => 
                                  IN_REQ <= '1';
                                  if IN_VLD = '1' then 
                                    IN_REQ <= '0';
                                    mx_sel <= "00";
                                    DATA_WREN <= '1';
                                    DATA_EN <= '1';
                                    fsm_signal <= s_input;
                                  end if;
                                  when x"7E" => 
                                  cnt_reg_inc <= '1';
                                  fsm_signal <= help_s_while_start;
                                  when x"00" => fsm_signal <= s_null;
                                  when others => fsm_signal <= s_start;
                          end case;
-----------------------------------------------								  
              when s_ptr_inc => 
                ptr_reg_inc <= '0';
                fsm_signal <= s_start;
-----------------------------------------------             
              when s_ptr_dec =>
                ptr_reg_dec <= '0';
                fsm_signal <= s_start;
-----------------------------------------------
              when s_val_inc =>
                DATA_EN <= '1';
                DATA_WREN <= '1';
                mx_sel <= "01";
                fsm_signal <= help_s_val_inc;

              when help_s_val_inc =>
                DATA_EN <= '0';
                fsm_signal <= s_start;
 -----------------------------------------------             
               when s_val_dec =>
                DATA_EN <= '1';
                DATA_WREN <= '1';
                mx_sel <= "10";
                fsm_signal <= help_s_val_dec;

              when help_s_val_dec =>
                DATA_EN <= '0';
                fsm_signal <= s_start;
 -----------------------------------------------             
              when s_while_start =>
                DATA_EN <= '0';
                
              fsm_signal <= helppppp_s_while_start;

                when helppppp_s_while_start =>
                  if por_dar = '1'  then
                  cnt_reg_inc <= '1';
                  fsm_signal <= help_s_while_start;  
                  else fsm_signal <= s_start;
                end if;

              when help_s_while_start => 
                 cnt_reg_inc <= '0';
                 pc_reg_inc <= '0';
                 CODE_EN <= '1';
                 fsm_signal <= helpp_s_while_start;
              
              when helpp_s_while_start =>
                 CODE_EN <= '0';
                 fsm_signal <= helppp_s_while_start;
              
              when helppp_s_while_start =>
                 if CODE_DATA = x"5D" then
                    cnt_reg_dec <= '1';
                  elsif CODE_DATA = x"5B" then 
                        cnt_reg_inc <= '1';
                  end if;
                 fsm_signal <= helpppp_s_while_start;
              
              when helpppp_s_while_start => 
                 cnt_reg_inc <= '0';
                 cnt_reg_dec <= '0';
                 if por_cnt = '1' then
                    fsm_signal <= s_start;
                  else pc_reg_inc <= '1';
                       fsm_signal <= help_s_while_start; 
                 end if ;
              
				  WHEN helppppp_s_while_end =>
					DATA_EN <= '0';
					fsm_signal <= s_while_end;
					
-----------------------------------------------

				  when s_while_end =>
                  
                  if por_dar = '1'  then
                    fsm_signal <= s_start;
                  else cnt_reg_inc <= '1';
                       pc_reg_dec <= '1';
                       fsm_signal <= help_s_while_end;
                  end if;
              
              when help_s_while_end =>
                    cnt_reg_inc <= '0';
                    fsm_signal <= helpp_s_while_end;

              when helpp_s_while_end =>
                    pc_reg_dec <= '0';
                    fsm_signal <= helpppppp_s_while_end;
                    CODE_EN <= '1';
				  when helpppppp_s_while_end =>
						CODE_EN <= '0';
						fsm_signal <= helppp_s_while_end;

              when helppp_s_while_end =>
						      if CODE_DATA = x"5D" then
                    cnt_reg_inc <= '1';
                  elsif CODE_DATA = x"5B" then 
                        cnt_reg_dec <= '1';
                  end if;
                fsm_signal <= helpppp_s_while_end;
              
              when helpppp_s_while_end =>
                      cnt_reg_inc <= '0';
                      cnt_reg_dec <= '0';
                      fsm_signal <= helppppppp_s_while_end;
              when helppppppp_s_while_end =>
                   if por_cnt = '1' then
                        fsm_signal <= s_start;
                      else fsm_signal <= helpp_s_while_end;
									pc_reg_dec <= '1';
                      end if;

-----------------------------------------------
							 
              when s_output =>
                OUT_WREN <= '0';
                fsm_signal <= s_start;
              when s_input =>
                DATA_EN <= '0';
                fsm_signal <= s_start;
              when others =>
    end case;
end if ;
end process;
 -- zde dopiste vlastni VHDL kod

 -- pri tvorbe kodu reflektujte rady ze cviceni INP, zejmena mejte na pameti, ze 
 --   - nelze z vice procesu ovladat stejny signal,
 --   - je vhodne mit jeden proces pro popis jedne hardwarove komponenty, protoze pak
 --      - u synchronnich komponent obsahuje sensitivity list pouze CLK a RESET a 
 --      - u kombinacnich komponent obsahuje sensitivity list vsechny ctene signaly.
end behavioral;
 
