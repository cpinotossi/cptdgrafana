// https://gist.github.com/smching/ff414e868e80a6ee2fbc8261f8aebb8f

var mqtt = require('mqtt');
require('dotenv').config();

var server = process.env.MQTTSERVER;
var topic = process.env.MQTTTOPIC;
var port = process.env.MQTTPORT;

var client = null;
if(process.env.MQTTUSERNAME){
    client = mqtt.connect(server, { clientId: "cptdgrafanapub", 
    port: port,
    username: process.env.MQTTUSERNAME,
    password: process.env.MQTTPASSWORD });
}else{
    client = mqtt.connect(server, { clientId: "cptdgrafanapub", port: port});
}

//handle incoming messages
client.on('message', function (topic, message) {
    console.log("[message]:" + message.toString());
    console.log("[topic]:" + topic.toString());
});

client.on("connect", function () {
    console.log("connected  " + client.connected);

})
//handle errors
client.on("error", function (error) {
    console.log("Can't connect" + error);
    process.exit(1)
});

console.log("subscribing to topics");
client.subscribe(topic, { qos: 1 }); //single topic
