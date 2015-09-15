library server;

import 'shared.dart';
import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:convert';

class WSConnection {
  static Map<int, WSConnection> instances = new Map();
  static int counter = 0;

  static Function handler;
  static Function logError = print;
  static Function logData = print;

  bool get sockRdy => (ws?.readyState == WebSocket.OPEN); //is websocket ready
  //bool readySnd = true; //Result is received and ready to send new message
  //bool get ready => (sockRdy && readySnd); //Everything is ready
  bool get connecting => (ws?.readyState != WebSocket.CONNECTING);

  //bool readyRcv = true; // Ready to send response
  //bool get readyR => (sockRdy && readyRcv); //Everything is ready for response

  String sesid;
  int id;
  HttpRequest req;
  WebSocket ws;

  Queue<Message> _messages = new Queue();
  Queue<Message> _responses = new Queue();

  MsgCache _sentMessages = new MsgCache();

  void handleMessage(dynamic message) {
    Message msg = new Message.fromJson(message);
    //print(msg); //Print received message

    if (msg.pth == "auth") {
      sesid = msg.msg["sesid"];
      //readyRcv = true;
      sendMessage("registered", "auth", id: msg.id, response:true);
    }
    else {
      Message cMsg = _sentMessages.findMsg(msg);
      if (cMsg != null) {
        //It's a response
        if (cMsg.handler != null) cMsg.handler(msg.msg); //This is answer for the current message
        _sentMessages.remove(cMsg.id); //Remove finished element
        sendEl(); //Send next element
      } else {
        //readyRcv = true;
        handleRequest(msg); //when is not a readponse
      }
    }
    //Handle websocket requests
    sendEl();
  }

  void sendEl() {
    //Schedule sending for later if queue is not empty
    if (!sockRdy) {
      instances.remove(id); // if socket is not ready remove from instances -> connection is broken
      ws.close();
      return;
    }

    //print("connid: $id ready: $ready readySnd:$readySnd msgLen:${_messages.length} readyR: $readyR readyRcv:$readyRcv rcvLen:${_responses.length}");

    if (sockRdy) {
      // If stream is ready send element
      if (_messages.length > 0) {
        Message cMsg = _messages.first; //Get first element from queue
        _messages.removeFirst(); //Remove first element from queue
        ws.add(JSON.encode(cMsg)); //Send current element
        _sentMessages.setMsg(cMsg); //Add message to sent Messages map
        //readySnd = false; //Set ready to send No
      }
    }

    if (sockRdy) {
      //Ready to send response
      if (_responses.length > 0) {
        Message cResp = _responses.first; //Get first element from queue
        _responses.removeFirst(); //Remove first element from queue
        ws.add(JSON.encode(cResp)); //Send current element
        //readyRcv = false; //Set ready to respond No
      }
    }
  }


  WSConnection(this.ws, this.req) {
    counter++;
    id = counter; //Create unique id
    instances[id] = this; //Add this instance to collection
    ws.listen((message) => handleMessage(message));
    Message.server = true; //Configure message ids for server
  }

  void sendMessageCB(dynamic message, String path, Function callBack, {int id, bool response:false}) {
    Message msg = new Message(message, path, callBack, id:id);
    //print("id:${msg.id} path:${msg.pth} ready:$ready readySnd:$readySnd");
    if (response) {
      _responses.add(msg); //Add the new response to be sent
      if (sockRdy) sendEl();  //if websocket is ready send first response from queue
    }
      else {
      _messages.add(msg); //Add the new message
      if (sockRdy) sendEl();  //if websocket is ready send first message from queue
    }
  }

  Future sendMessage(dynamic message, String path, {int id, bool response: false}) {
    Completer comp = new Completer();
    sendMessageCB(message, path, (res) => comp.complete(res), id:id, response: response);
    return comp.future;
  }

  void handleRequest(Message msg) {
    //logData(msg.toString());
    Message cMsg = _sentMessages.findMsg(msg);
    if (cMsg != null) {
      //This is a message response
      if (cMsg?.handler != null) cMsg.handler(msg); //This is answer for the current message
      _sentMessages.remove(cMsg.id); //Remove message from sent map
      //readySnd = true; //Ready to send Yes
    } else {
      //This is a new message from client
      /* execCommand(String cmd, Map pData, Function callBack) */
      Map pData;
      try { pData = msg.msg as Map; } catch (err) { print("Error: $msg ||| $err"); pData = new Map(); }

      //Set login parameters to execution map
      pData["login"] = sesid;
      pData["ip"] = req.connectionInfo.remoteAddress;
      //print (pData.toString()); //Print map to be passed to handler

      if (handler != null) handler(msg.pth, pData, ((res) => sendMessageCB(res, msg.pth, null, id: msg.id, response:true)));
    }
  }
}

class WSServer {
  static const String wsPath = "/ws";
  static Function get logError => WSConnection.logError;
  static Function get logData => WSConnection.logData;

  static void wsCheck(HttpRequest req) {
    if (req.uri.path == wsPath) WebSocketTransformer.upgrade(req).then((
        WebSocket ws) {
        //We have websocket ready -> save it and handle it

        ws.pingInterval = const Duration(seconds:55);
        new WSConnection(ws, req); //Create unregistered session
    })
    .catchError((err) => logError("WSerror: "+err.toString()));
  }
}
