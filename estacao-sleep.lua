-- Fatec Jundiai - Estacao Meteorologica
-- v1.0 (24/9/18)
-- Prof. Claudio L. V. Oliveira

ACESSO        = {}
ACESSO.ssid   = "AP"
ACESSO.pwd    = "SENHA"
ACESSO.save   = false

ALARME_CON    = 0
ALARME_ENV    = 1
ALARME_DORMIR = 2
ALARME_IP     = 3
ALARME_DADOS  = 4

SEG_PARA_US   = 1000000
SEG_PARA_MS   = 1000
MS_PARA_US    = 1000

DEPURAR       = true
CHAVE_THNGSPK = "CHAVE"

-- Pinos utilizados
-- DHT11
PINO_DHT      = 5
-- BMP180 e LCD i2c
SDA, SCL      = 1, 2


-- Exibir no LCD e no console (se DEPURAR true)
function exibir(linha, coluna, texto)
  lcd:put(lcd:locate(linha, coluna), texto)
  if DEPURAR == true then
    print (texto)
  end
end

-- Conexão ao Access Point
function Conectar()
  lcd:clear()
  exibir(0, 0, "Conectando ao")
  exibir(1, 0, "WIFI...")
  wifi.setmode(wifi.STATION)
  wifi.sta.config(ACESSO)
  wifi.sta.connect()
  tmr.alarm(ALARME_IP, 2 * SEG_PARA_MS, tmr.ALARM_AUTO, function() 
    if wifi.sta.getip()== nil then 
      lcd:clear()
      exibir(0, 0, "Ip nao disp.")
      exibir(1, 0, "Aguardando...")
    else 
      tmr.stop(ALARME_IP)
      lcd:clear()
      exibir(0, 0, "Conexao Ok! IP:")
      exibir(1, 0, "" .. wifi.sta.getip())
    end 
  end)
end

-- Obter os dados do BMP180 e do DHT11
function GetDados()
  bmp085.setup()
  p = bmp085.pressure()
  p_dec = p % 100
  p = p / 100
  p = p .. "." .. p_dec
    
  status, t, u, t_dec, u_dec = dht.read(PINO_DHT)
  if status == dht.OK then
    t = t .. "." .. t_dec
    u = u .. "." .. u_dec
    tmr.alarm(ALARME_DADOS, 2 * SEG_PARA_MS, tmr.ALARM_SINGLE, function ()
      lcd:clear()
      exibir(0, 0, "T:" .. t .. "C U:" .. u .. "%")
      exibir(1, 0, "P:" .. p .."mbar")
    end)  
  else
    print ("\nErro na leitura dos sensores\n")
    lcd:clear()
    exibir(0, 0, "Erro sensores!")
  end
  return t, u, p
end

--- Enviar os dados para o site thingspeak.com
function TransmitirDados()
  temperatura, umidade, pressao = GetDados()
  -- Conexão
  lcd:clear()
  exibir(0, 0, "Enviando dados..")
  conn=net.createConnection(net.TCP, 0) 
  conn:on("receive", function(conn, payload) 
    exibir(1, 0, payload) 
  end)
  -- api.thingspeak.com 184.106.153.149
  conn:connect(80, '184.106.153.149') 
  conn:send("GET /update?key=" .. CHAVE_THNGSPK .. "&field1=".. temperatura .. 
    "&field2=" .. umidade .. "&field3=" .. pressao .. " HTTP/1.1\r\n") 
  conn:send("Host: api.thingspeak.com\r\n") 
  conn:send("Accept: */*\r\n") 
  conn:send("User-Agent: Mozilla/4.0 (compatible; esp8266 Lua; Windows NT 5.1)\r\n")
  conn:send("\r\n")
  conn:on("sent", function(conn)
    print("Concluido.")
    exibir(1, 0, "Concluido.")
    conn:close()
  end)
  conn:on("disconnection", function(conn)
    exibir(1, 0, "Conexao encerrada.")
  end)
end

-- Rotina Principal
i2c.setup(0, SDA, SCL, i2c.SLOW)
lcd = dofile("lcd1602_lib.lua")()
exibir(0, 0, "Fatec Jundiai")
exibir(1, 0, "E. Meteorologica")
tmr.alarm(ALARME_CON, 10 * SEG_PARA_MS, tmr.ALARM_SINGLE, function ()
  Conectar()
end)

tmr.alarm(ALARME_ENV, 60 * SEG_PARA_MS, tmr.ALARM_SINGLE, function ()
  TransmitirDados()
end)

tmr.alarm(ALARME_DORMIR, 120 * SEG_PARA_MS, tmr.ALARM_SINGLE, function ()
  exibir(0, 0, "Indo dormir...")
  tmr.delay(250 * MS_PARA_US)
  -- NodeMCU RST e D0 (GPIO16) devem estar conectados
  node.dsleep(600 * SEG_PARA_US, 4)
end)
