#!/usr/bin/env python3
html = """<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>S4 Control</title>
<style>body{font-family:Arial;background:#1a1a2e;color:#eee;padding:20px}
.header{background:linear-gradient(135deg,#667eea,#764ba2);padding:20px;text-align:center}
.card{background:#16213e;border-radius:15px;padding:20px;margin:20px 0}
.btn{background:#667eea;color:white;border:none;padding:15px 30px;border-radius:8px;cursor:pointer;margin:5px}
.btn-danger{background:#e74c3c}.btn-success{background:#2ecc71}
.slider{width:100%;height:8px;-webkit-appearance:none}
.estop-indicator{background:#e74c3c;color:white;padding:15px;display:none}
.estop-indicator.active{display:block}
</style></head><body>
<div class="header"><h1>Blueberry S4</h1><p>4WS AGV Control</p></div>
<div class="card"><h3>Connection</h3>
<input type="text" id="ws-url" value="ws://localhost:9091" style="padding:10px;width:300px">
<button class="btn" onclick="toggle()">Connect</button>
</div><div class="card"><h3>Control</h3>
<div>Linear Speed (m/s): <span id="lin-val">0</span></div>
<input type="range" class="slider" id="lin" min="-2" max="2" step="0.1" value="0" oninput="update()" onchange="send()">
<div>Angular Speed (rad/s): <span id="ang-val">0</span></div>
<input type="range" class="slider" id="ang" min="-1" max="1" step="0.1" value="0" oninput="update()" onchange="send()">
<div>Gear: <span id="gear-txt">DRIVE</span></div>
<button class="btn" onclick="setGear(0)">NEUTRAL</button>
<button class="btn btn-success" onclick="setGear(1)">DRIVE</button>
<button class="btn" style="background:#f39c12" onclick="setGear(2)">REVERSE</button>
<br><br><button class="btn btn-danger" onclick="estop()">EMERGENCY STOP</button>
<button class="btn btn-success" onclick="clearEstop()">Clear</button>
<button class="btn" onclick="stop()">STOP</button>
</div><div class="estop-indicator" id="estop">EMERGENCY STOP ACTIVE</div>
<script>
let ws=null,conn=false,gear=1,estopActive=false;
function update(){document.getElementById("lin-val").textContent=document.getElementById("lin").value;document.getElementById("ang-val").textContent=document.getElementById("ang").value;}
function setGear(g){gear=g;document.getElementById("gear-txt").textContent=["NEUTRAL","DRIVE","REVERSE"][g];send();}
function toggle(){if(conn){ws.close();return;}ws=new WebSocket(document.getElementById("ws-url").value);ws.onopen=function(){conn=true;ws.send(JSON.stringify({op:"subscribe",topic:"/chassis_info_fb"}));ws.send(JSON.stringify({op:"advertise",topic:"/ctrl_cmd",type:"yhs_can_interfaces/CtrlCmd"}));};ws.onmessage=function(e){let m=JSON.parse(e.data);if(m.topic=="/chassis_info_fb"&&m.msg)console.log("recv",m.msg);};ws.onclose=function(){conn=false;};}
function send(){if(!conn||estopActive)return;ws.send(JSON.stringify({op:"publish",topic:"/ctrl_cmd",msg:{ctrl_cmd_gear:gear,ctrl_cmd_x_linear:parseFloat(document.getElementById("lin").value),ctrl_cmd_z_angular:parseFloat(document.getElementById("ang").value),ctrl_cmd_y_linear:0}}));}
function estop(){estopActive=true;document.getElementById("estop").className="estop-indicator active";if(conn)ws.send(JSON.stringify({op:"publish",topic:"/ctrl_cmd",msg:{ctrl_cmd_gear:0,ctrl_cmd_x_linear:0,ctrl_cmd_z_angular:0,ctrl_cmd_y_linear:0}}));}
function clearEstop(){estopActive=false;document.getElementById("estop").className="estop-indicator";}
function stop(){document.getElementById("lin").value=0;document.getElementById("ang").value=0;update();send();}
</script></body></html>"""
open("index.html","w").write(html)
print("Generated index.html")
