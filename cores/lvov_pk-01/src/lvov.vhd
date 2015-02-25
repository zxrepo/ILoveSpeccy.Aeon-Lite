library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

entity lvov is
Port (
   CLK50       : IN  STD_LOGIC;
   
   PS2_CLK     : in  STD_LOGIC;
   PS2_DATA    : in  STD_LOGIC;
   
   SRAM_A      : out    std_logic_vector(17 downto 0);
   SRAM_D      : inout  std_logic_vector(15 downto 0);
   SRAM_WE     : out    std_logic;
   SRAM_OE     : out    std_logic;
   SRAM_CS     : out    std_logic;
   SRAM_LB     : out    std_logic;
   SRAM_UB     : out    std_logic;

   SOUND_L     : out    std_logic;
   SOUND_R     : out    std_logic;

   SD_MOSI     : out   std_logic;
   SD_MISO     : in    std_logic;
   SD_SCK      : out   std_logic;
   SD_CS       : out   std_logic; 
   
   VGA_R       : OUT STD_LOGIC_VECTOR(3 downto 0);
   VGA_G       : OUT STD_LOGIC_VECTOR(3 downto 0);
   VGA_B       : OUT STD_LOGIC_VECTOR(3 downto 0);
   VGA_HSYNC   : OUT STD_LOGIC;
   VGA_VSYNC   : OUT STD_LOGIC );
end lvov;

architecture Behavioral of lvov is

   component k580wm80a is
   port(
      clk      : in  std_logic;
      ce       : in  std_logic;
      reset    : in  std_logic;
      intr     : in  std_logic;
      idata    : in  std_logic_vector(7 downto 0);
      addr     : out std_logic_vector(15 downto 0);
      sync     : out std_logic;
      rd       : out std_logic;
      wr_n     : out std_logic;
      inta_n   : out std_logic;
      odata    : out std_logic_vector(7 downto 0);
      inte_o   : out std_logic );
   end component;

   signal CLK        : std_logic;
   signal RESET      : std_logic := '0';
   signal TICK       : std_logic_vector(3 downto 0) := "0000"; 
   
   signal SRAM_DI    : std_logic_vector(7 downto 0);
   signal SRAM_DO    : std_logic_vector(7 downto 0);

   signal KEYB_A     : std_logic_vector(7 downto 0);
   signal KEYB_D     : std_logic_vector(7 downto 0);   
   signal KEYB_A2    : std_logic_vector(3 downto 0);
   signal KEYB_D2    : std_logic_vector(3 downto 0);   
   signal KEYB_CTRL  : std_logic_vector(7 downto 0);   
   
   signal COLORS     : std_logic_vector(6 downto 0);
   signal ROM_D      : std_logic_vector(7 downto 0);   
   
   signal ROM_INIT   : std_logic;

   signal CPU_CLK    : std_logic;
   signal CPU_SYNC   : std_logic;
   signal CPU_RD     : std_logic;
   signal CPU_WR_N   : std_logic;
   signal CPU_A      : std_logic_vector(15 downto 0);
   signal CPU_DI     : std_logic_vector(7 downto 0);
   signal CPU_DO     : std_logic_vector(7 downto 0);
   
   signal IO_RD      : std_logic;
   signal IO_WR      : std_logic;
   signal MEM_RD     : std_logic;
   signal MEM_WR     : std_logic;

   signal XSD_EN     : std_logic;
   signal XSDROM_D   : std_logic_vector(7 downto 0);   
   signal XSDRAM_DO  : std_logic_vector(7 downto 0);   
   signal XSDRAM_WE  : std_logic_vector(0 downto 0);
   signal SD_CLK_R   : std_logic;
   signal SD_DATA    : std_logic_vector(6 downto 0);   
   signal SD_O       : std_logic_vector(7 downto 0);   
   
   signal VRAM_DO    : std_logic_vector(7 downto 0);
   signal VRAM_WE    : std_logic_vector(0 downto 0);
   signal VRAM_VA    : std_logic_vector(13 downto 0);   
   signal VRAM_VD    : std_logic_vector(7 downto 0);
   signal VRAM_CS    : std_logic;

   -- FSM States
   type STATE_TYPE is ( IDLE, RAMREAD1, RAMWRITE1, RAMWRITE2 );
   signal STATE : STATE_TYPE := IDLE;
   
begin

   u_CLOCK : entity work.clock
   port map(
      CLK_IN      => CLK50,
      CLK_OUT     => CLK );

   u_ROM : entity work.rom
   port map(
      CLKA        => CLK,
      ADDRA       => CPU_A(13 downto 0),
      DOUTA       => ROM_D );

   u_XSDROM : entity work.xsd_rom
   port map(
      CLKA        => CLK,
      ADDRA       => CPU_A(10 downto 0),
      DOUTA       => XSDROM_D );

   u_XSDRAM : entity work.xsd_ram
   port map(
      CLKA        => CLK,
      WEA         => XSDRAM_WE,
      ADDRA       => CPU_A(10 downto 0),
      DINA        => CPU_DO,
      DOUTA       => XSDRAM_DO );

   u_CPU : k580wm80a
   port map(
      clk            => CLK,
      ce             => CPU_CLK,
      reset          => not RESET,
      intr           => '0',
      idata          => CPU_DI,
      addr           => CPU_A,
      sync           => CPU_SYNC,
      rd             => CPU_RD,
      wr_n           => CPU_WR_N,
      inta_n         => OPEN,
      odata          => CPU_DO,
      inte_o         => OPEN );
   
   u_VIDEO : entity work.video
   port map(
      CLK         => CLK,
      RESET       => '1',
      VRAM_A      => VRAM_VA,
      VRAM_D      => VRAM_VD,
      COLORS      => COLORS,
      R           => VGA_R,
      G           => VGA_G,
      B           => VGA_B,
      HSYNC       => VGA_HSYNC,
      VSYNC       => VGA_VSYNC ); 
      
   u_VRAM : entity work.vram
   port map(
      clka        => CLK,
      wea         => VRAM_WE,
      addra       => CPU_A(13 downto 0),
      dina        => CPU_DO,
      douta       => VRAM_DO,
      clkb        => CLK,
      web         => "0",
      addrb       => VRAM_VA,
      dinb        => "11111111",
      doutb       => VRAM_VD );
      
   u_KEYBOARD : entity work.keyboard
   port map(
      CLK         => CLK,
      RESET       => RESET,
      PS2_CLK     => PS2_CLK,
      PS2_DATA    => PS2_DATA,
      CONTROL     => KEYB_CTRL,
      KEYB_A      => KEYB_A,
      KEYB_D      => KEYB_D,
      KEYB_A2     => KEYB_A2,
      KEYB_D2     => KEYB_D2 );
      
   SRAM_LB   <= '0';
   SRAM_UB   <= '1';
   SRAM_A <= "00" & CPU_A;
   SRAM_D    <= "ZZZZZZZZ" & SRAM_DI;
   SRAM_DO   <= SRAM_D(7 downto 0);

   process(CLK)
   begin
      if rising_edge(CLK) then
         if RESET = '0' then
            MEM_WR <= '1';
            MEM_RD <= '1';
            IO_WR <= '1';
            IO_RD <= '1';
         else
            if CPU_SYNC = '1' then

               MEM_WR <= '1';
               MEM_RD <= '1';
               IO_WR <= '1';
               IO_RD <= '1';

               if CPU_DO(4) = '1' then
                  IO_WR <= '0';
               elsif CPU_DO(6) = '1' then
                  IO_RD <= '0';
               elsif CPU_DO(7) = '1' then
                  MEM_RD <= '0';
               elsif CPU_DO(7) = '0' then
                  MEM_WR <= '0';
               end if;

            end if;
         end if;
      end if;
   end process;
      
   CLOCK : process(CLK)
   begin
      if rising_edge(CLK) then
         if KEYB_CTRL(0) = '1' then
            TICK <= (others => '0');
            RESET <= '0';
         else
            TICK <= TICK + 1;
            CPU_CLK <= '0';
            if TICK = "1111" then  -- Generate 2.16MHz (32.5MHz/15) CPU Clock (Original 2.22MHz (20MHz/9))
               CPU_CLK <= '1';
               TICK <= (others => '0');
               RESET <= '1';
            end if;
         end if;
      end if;
   end process;    

   FSM : process(CLK)
   begin
      if rising_edge(CLK) then
         if RESET = '0' then
            SRAM_WE  <= '1';
            SRAM_OE  <= '1';
            SRAM_CS  <= '1';
            SRAM_DI  <= (others => 'Z');
            XSD_EN <= '0';
            VRAM_WE <= "0";
            XSDRAM_WE <= "0";
            ROM_INIT <= '1';
         else
         
            VRAM_WE <= "0";
            XSDRAM_WE <= "0";

            case STATE is
                           
               when IDLE =>

                  if TICK = 1 then
                     if MEM_RD = '0' and CPU_RD = '1' then ------------------------------------------------------------------------- Read from Memory
                        if CPU_A(15 downto 11) = "11000" and XSD_EN = '1' then
                           CPU_DI <= XSDRAM_DO;
                        elsif (CPU_A(15) = '1' and CPU_A(14) = '1') or ROM_INIT = '1' then            -- Read from ROM
                           CPU_DI <= ROM_D;
                        elsif CPU_A(15 downto 11) = "00000" and XSD_EN = '1' then
                           CPU_DI <= XSDROM_D;
                        else                                                                       -- Read from RAM
                           if CPU_A(15) = '0' and VRAM_CS = '0' then
                              CPU_DI <= VRAM_DO;
                           end if;
                           SRAM_OE  <= '0';
                           SRAM_CS  <= '0';                           
                           STATE    <= RAMREAD1;
                        end if;
                     elsif MEM_WR = '0' and CPU_WR_N = '0' then ---------------------------------------------------------------------- Write to Memory
                        if CPU_A(15) = '0' and VRAM_CS = '0' then
                           VRAM_WE <= "1";
                        end if;
                        if CPU_A(15 downto 11) = "11000" and XSD_EN = '1' then
                           XSDRAM_WE <= "1";
                        end if;
                        SRAM_WE  <= '0';
                        SRAM_CS  <= '0';                           
                        SRAM_DI  <= CPU_DO;
                        STATE    <= RAMWRITE1;
                        
                     elsif IO_RD = '0' and CPU_RD = '1' then ---------------------------------------------------------------------- Read from I/O-Ports
                     
                        CPU_DI <= (others => '1');
                        ROM_INIT <= '0';

                        if CPU_A(7 downto 0) = X"F1" then
                           CPU_DI <= SD_O;
--                        elsif CPU_A(4) ='0' and CPU_A(3) = '0' and CPU_A(1 downto 0) = "10" then
--                           CPU_DI <= "111" & TAPE_IN & "1111";
                        elsif CPU_A(4) = '1' and CPU_A(3) = '0' and CPU_A(1 downto 0) = "01" then
                           CPU_DI <= KEYB_D;
                        elsif CPU_A(4) = '1' and CPU_A(3) = '0' and CPU_A(1 downto 0) = "10" then
                           CPU_DI <= KEYB_D2 & KEYB_A2;
                        end if;

                     elsif IO_WR = '0' and CPU_WR_N = '0' then ---------------------------------------------------------------------- Write to I/O-Ports
                     
                        ROM_INIT <= '0';

                        if CPU_A(7 downto 0) = X"FF" then
                           XSD_EN <= CPU_DO(1);
                        elsif CPU_A(4) = '0' and CPU_A(3) = '0' and CPU_A(1 downto 0) = "01" then
                           COLORS <= CPU_DO(6 downto 0);
                        elsif CPU_A(4) = '0' and CPU_A(3) = '0' and CPU_A(1 downto 0) = "10" then
                           VRAM_CS <= CPU_DO(1);
                           SOUND_L <= CPU_DO(0);
                           SOUND_R <= CPU_DO(0);
                        elsif CPU_A(4) = '1' and CPU_A(3) = '0' and CPU_A(1 downto 0) = "00" then
                           KEYB_A <= CPU_DO;
                        elsif CPU_A(4) = '1' and CPU_A(3) = '0' and CPU_A(1 downto 0) = "10" then
                           KEYB_A2 <= CPU_DO(3 downto 0);
                        end if;
                        
                     end if;
                  end if;
                                    
               when RAMREAD1 =>
                  SRAM_OE  <= '1';
                  SRAM_CS  <= '1';                           
                  CPU_DI <= SRAM_DO;
                  STATE    <= IDLE;                  

               when RAMWRITE1 =>
                  SRAM_WE  <= '1';
                  SRAM_CS  <= '1';                           
                  STATE    <= RAMWRITE2;                  

               when RAMWRITE2 =>
                  SRAM_DI <= (others => 'Z');
                  STATE    <= IDLE;                  
                  
               when OTHERS =>
                  STATE <= IDLE;
                  
            end case;   
         end if;
      end if;
   end process;    
   
--////////////////////   SD CARD   ////////////////////

SD_O <= SD_DATA & SD_MISO;
SD_SCK <= SD_CLK_R;

process(CLK)
begin
   if RESET = '0' then
      SD_CS <= '1';
      SD_MOSI <= '1';
      SD_CLK_R <= '0';
   elsif rising_edge(CLK) then
      if IO_WR = '0' and CPU_A(7 downto 0) = X"F0" then
         SD_CS <= not CPU_DO(0);
      elsif IO_WR = '0' and CPU_A(7 downto 0) = X"F1" then
         if SD_CLK_R = '1' then
            SD_DATA <= SD_DATA(5 downto 0) & SD_MISO;
         end if;
         SD_MOSI <= CPU_DO(7);
         SD_CLK_R <= '0';
      end if;
      if IO_RD = '0' or MEM_RD = '0' then
         SD_CLK_R <= '1';
      end if;
   end if;
end process;

end Behavioral;
