// Blueberry S4 AGV Control Dashboard
let ws = null;
let connected = false;
let currentGear = 6;  // 4T4D mode (four-wheel steering + four-wheel drive)
let estopActive = false;

// Initialize
function init() {
    updateDisplay();
    console.log('Dashboard initialized');
}

// Update slider value displays
function updateDisplay() {
    const lin = document.getElementById('linear-speed').value;
    const ang = document.getElementById('angular-speed').value;
    document.getElementById('lin-val').textContent = parseFloat(lin).toFixed(1) + ' m/s';
    document.getElementById('ang-val').textContent = parseFloat(ang).toFixed(1) + ' rad/s';
}

// Set gear
// Gear values per YUHESEN protocol:
// 0x00 = Disable, 0x01 = Parking, 0x02 = Neutral
// 0x06 = 4T4D (four-wheel steering + four-wheel drive) - for normal driving
// 0x08 = Lateral (crab steering)
function setGear(g) {
    currentGear = g;
    const names = {0: 'DISABLE', 1: 'PARK', 2: 'NEUTRAL', 6: '4T4D', 8: 'LATERAL'};
    document.getElementById('gear-display').textContent = names[g] || 'UNKNOWN';
    // Update button styles
    document.getElementById('gear-0').className = g === 0 ? 'btn-neutral active' : 'btn-neutral';
    document.getElementById('gear-1').className = g === 1 ? 'btn-drive active' : 'btn-drive';
    document.getElementById('gear-2').className = g === 2 ? 'btn-reverse active' : 'btn-reverse';
    sendCommand();
}

// Connect/Disconnect WebSocket
function toggleConnection() {
    if (connected) {
        ws.close();
        return;
    }
    
    const url = document.getElementById('rosbridge-url').value;
    console.log('Connecting to:', url);
    
    ws = new WebSocket(url);
    
    ws.onopen = function() {
        connected = true;
        document.getElementById('connection-status').className = 'status-dot connected';
        document.getElementById('connection-text').textContent = 'Connected';
        document.getElementById('connect-btn').textContent = 'Disconnect';
        console.log('WebSocket connected');
        
        // Subscribe to topics
        ws.send(JSON.stringify({
            op: 'subscribe',
            topic: '/chassis_info_fb'
        }));
        
        // Advertise publishers
        ws.send(JSON.stringify({
            op: 'advertise',
            topic: '/ctrl_cmd',
            type: 'yhs_can_interfaces/CtrlCmd'
        }));
        ws.send(JSON.stringify({
            op: 'advertise',
            topic: '/io_cmd',
            type: 'yhs_can_interfaces/IoCmd'
        }));
        
        // Send initial unlock sequence
        sendUnlockSequence();
    };
    
    // Send unlock sequence to enable vehicle control
    function sendUnlockSequence() {
        console.log('Sending unlock sequence...');
        // Unlock sequence: 0x02 -> 0x02 -> 0x00 -> 0x00 with 20ms intervals
        const sequence = [true, true, false, false];
        let step = 0;
        
        function sendStep() {
            if (step < sequence.length && connected) {
                ws.send(JSON.stringify({
                    op: 'publish',
                    topic: '/io_cmd',
                    msg: {
                        io_cmd_unlock: sequence[step],
                        io_cmd_lamp_ctrl: true
                    }
                }));
                console.log('Unlock step', step, ': unlock =', sequence[step]);
                step++;
                setTimeout(sendStep, 20); // 20ms interval
            } else {
                console.log('Unlock sequence complete');
                // Continue sending unlock=true to maintain unlock state
                setInterval(() => {
                    if (connected) {
                        ws.send(JSON.stringify({
                            op: 'publish',
                            topic: '/io_cmd',
                            msg: {
                                io_cmd_unlock: true,
                                io_cmd_lamp_ctrl: true
                            }
                        }));
                    }
                }, 100); // 10Hz to maintain unlock
            }
        }
        sendStep();
    }
    
    ws.onmessage = function(e) {
        const msg = JSON.parse(e.data);
        if (msg.topic === '/chassis_info_fb' && msg.msg) {
            updateStatus(msg.msg);
        }
    };
    
    ws.onclose = function() {
        connected = false;
        document.getElementById('connection-status').className = 'status-dot';
        document.getElementById('connection-text').textContent = 'Disconnected';
        document.getElementById('connect-btn').textContent = 'Connect';
        console.log('WebSocket disconnected');
    };
    
    ws.onerror = function(err) {
        console.error('WebSocket error:', err);
    };
}

// Update vehicle status display
function updateStatus(data) {
    if (data.ctrl_fb) {
        document.getElementById('lin-vel').textContent = data.ctrl_fb.ctrl_fb_x_linear.toFixed(2);
        document.getElementById('ang-vel').textContent = data.ctrl_fb.ctrl_fb_z_angular.toFixed(2);
    }
    if (data.bms_fb) {
        document.getElementById('battery-voltage').textContent = data.bms_fb.bms_fb_voltage.toFixed(1);
    }
    if (data.bms_flag_fb) {
        document.getElementById('battery-soc').textContent = data.bms_flag_fb.bms_flag_fb_soc;
    }
}

// Send control command
function sendCommand() {
    if (!connected || estopActive) return;
    
    const lin = parseFloat(document.getElementById('linear-speed').value);
    const ang = parseFloat(document.getElementById('angular-speed').value);
    
    const cmd = {
        op: 'publish',
        topic: '/ctrl_cmd',
        msg: {
            ctrl_cmd_gear: currentGear,
            ctrl_cmd_x_linear: lin,
            ctrl_cmd_z_angular: ang,
            ctrl_cmd_y_linear: 0
        }
    };
    
    ws.send(JSON.stringify(cmd));
    console.log('Sent command:', cmd.msg);
}

// Emergency Stop
function triggerEstop() {
    estopActive = true;
    document.getElementById('estop-banner').className = 'estop-banner active';
    
    if (connected) {
        ws.send(JSON.stringify({
            op: 'publish',
            topic: '/ctrl_cmd',
            msg: {
                ctrl_cmd_gear: 0,
                ctrl_cmd_x_linear: 0,
                ctrl_cmd_z_angular: 0,
                ctrl_cmd_y_linear: 0
            }
        }));
    }
    
    // Reset sliders
    document.getElementById('linear-speed').value = 0;
    document.getElementById('angular-speed').value = 0;
    updateDisplay();
    console.log('EMERGENCY STOP activated');
}

// Clear E-Stop
function clearEstop() {
    estopActive = false;
    document.getElementById('estop-banner').className = 'estop-banner';
    console.log('E-Stop cleared');
}

// Stop motion (zero speed but keep gear)
function stopMotion() {
    document.getElementById('linear-speed').value = 0;
    document.getElementById('angular-speed').value = 0;
    updateDisplay();
    sendCommand();
    console.log('Motion stopped');
}

// Keyboard controls - bind after DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    console.log('Binding keyboard controls');
    
    document.addEventListener('keydown', function(e) {
        console.log('Key pressed:', e.key, 'Connected:', connected, 'E-stop:', estopActive);
        
        if (!connected || estopActive) {
            console.log('Keyboard input ignored - not connected or e-stop active');
            return;
        }
        
        const linSlider = document.getElementById('linear-speed');
        const angSlider = document.getElementById('angular-speed');
        let changed = false;
        
        switch(e.key) {
            case 'w':
            case 'W':
            case 'ArrowUp':
                linSlider.value = Math.min(2, parseFloat(linSlider.value) + 0.1);
                changed = true;
                e.preventDefault();
                break;
            case 's':
            case 'S':
            case 'ArrowDown':
                linSlider.value = Math.max(-2, parseFloat(linSlider.value) - 0.1);
                changed = true;
                e.preventDefault();
                break;
            case 'a':
            case 'A':
            case 'ArrowLeft':
                angSlider.value = Math.max(-1, parseFloat(angSlider.value) - 0.1);
                changed = true;
                e.preventDefault();
                break;
            case 'd':
            case 'D':
            case 'ArrowRight':
                angSlider.value = Math.min(1, parseFloat(angSlider.value) + 0.1);
                changed = true;
                e.preventDefault();
                break;
            case ' ':
            case 'Spacebar':
                stopMotion();
                e.preventDefault();
                break;
        }
        
        if (changed) {
            updateDisplay();
            sendCommand();
            console.log('New values - Linear:', linSlider.value, 'Angular:', angSlider.value);
        }
    });
});

// Initialize on load
window.onload = init;
