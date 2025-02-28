var express = require('express');
var app = express();
var http = require('http').Server(app);
var io = require('socket.io')(http);
var exec = require('child_process').exec;
var port = process.env.PORT || 3000;

var ads1x15 = require('node-ads1x15');
var adc = new ads1x15(1); // 1 for ADS1115, 0 for ADS1015

var Gpio = require('pigpio').Gpio;
var A1 = new Gpio(27, { mode: Gpio.OUTPUT });
var A2 = new Gpio(17, { mode: Gpio.OUTPUT });
var B1 = new Gpio(4, { mode: Gpio.OUTPUT });
var B2 = new Gpio(18, { mode: Gpio.OUTPUT });
var LED = new Gpio(22, { mode: Gpio.OUTPUT });

// Serve Touch.html
app.get('/', function (req, res) {
  res.sendFile(__dirname + '/Touch.html');
  console.log('HTML sent to client');
});

// Start MJPG streamer
exec('sudo bash start_stream.sh', function (error) {
  if (error) console.error('Streamer error:', error);
});

// Socket.IO connection
io.on('connection', function (socket) {
  console.log('A user connected');

  socket.on('pos', function (msx, msy) {
    msx = Math.min(Math.max(parseInt(msx, 10), -255), 255);
    msy = Math.min(Math.max(parseInt(msy, 10), -255), 255);

    if (msx > 0) {
      A1.pwmWrite(msx);
      A2.pwmWrite(0);
    } else {
      A1.pwmWrite(0);
      A2.pwmWrite(Math.abs(msx));
    }

    if (msy > 0) {
      B1.pwmWrite(msy);
      B2.pwmWrite(0);
    } else {
      B1.pwmWrite(0);
      B2.pwmWrite(Math.abs(msy));
    }
  });

  socket.on('light', function (toggle) {
    LED.digitalWrite(toggle ? 1 : 0);
  });

  socket.on('cam', function () {
    console.log('Taking a picture...');
    exec("find . -type f -name '*.jpg' | wc -l", function (error, stdout) {
      if (error) return console.error('Count error:', error);
      var numPics = parseInt(stdout, 10) + 1;
      var command =
        'sudo killall mjpg_streamer; raspistill -o cam' +
        numPics +
        '.jpg -n && sudo bash start_stream.sh';
      exec(command, function (error) {
        if (error) console.error('Camera error:', error);
        else socket.emit('cam', 1);
      });
    });
  });

  socket.on('power', function () {
    exec('sudo poweroff', function (error) {
      if (error) console.error('Poweroff error:', error);
    });
  });

  socket.on('disconnect', function () {
    console.log('A user disconnected');
  });

  setInterval(function () {
    exec('cat /sys/class/thermal/thermal_zone0/temp', function (error, stdout) {
      if (!error) {
        var temp = parseFloat(stdout) / 1000;
        socket.emit('temp', temp);
        console.log('Temp:', temp);
      }
    });

    if (!adc.busy) {
      adc.readADCSingleEnded(0, '4096', '250', function (err, data) {
        if (!err) {
          var voltage = (2 * parseFloat(data)) / 1000;
          socket.emit('volt', voltage);
          console.log('ADC:', voltage);
        }
      });
    }
  }, 5000);
});

http.listen(port, function () {
  console.log('Listening on *:' + port);
});