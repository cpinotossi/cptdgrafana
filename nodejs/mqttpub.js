var mqtt = require('mqtt');
require('dotenv').config();
const fs = require('fs');
const { randomInt } = require('crypto');

var server = process.env.MQTTSERVER;
var topic = process.env.MQTTTOPIC;
var port = process.env.MQTTPORT;

let mq = null;
let client = null;

fs.readFile('./movie_quotes.json', 'utf8', (err, data) => {
    if (err) {
        console.log(`Error reading file from disk: ${err}`);
    } else {
        // parse JSON string to JSON object
        mq = JSON.parse(data);
        if(process.env.MQTTUSERNAME){
            client = mqtt.connect(server, { clientId: "cptdgrafanapub", 
            port: port,
            username: process.env.MQTTUSERNAME,
            password: process.env.MQTTPASSWORD });
        }else{
            client = mqtt.connect(server, { clientId: "cptdgrafanapub", port: port});
        }
        client.on('connect', mqtt_connect);
        client.on('error', mqtt_error);
        client.subscribe(topic, { qos: 1 }); //single topic
    }
});

function mqtt_connect() {
    console.log("connected  " + client.connected);
    publish();
}

//handle errors
function mqtt_error() {
    console.log("Can't connect" + error);
    process.exit(1)
};

//publish
function publish() {
    var timer_id = setInterval(function () { 
        let quoteIndex = randomInt(0, 731);
        let message = `${mq[quoteIndex].quote}: ${mq[quoteIndex].movie}`;
        console.log("publishing", message);
        client.publish(topic, message, {retain: true,qos: 1}); }, 10000);
}