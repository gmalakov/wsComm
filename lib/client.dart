library client;

import 'dart:html';
import 'dart:async';
import 'shared.dart';
import 'dart:convert';
import 'dart:collection';

class WSCarrier {
  String _WSPath; // etc ws://echo.websocket.org
  set WSPath(String pth) {
    _WSPath = pth;
    initWebSocket();
  }

  WebSocket _ws;
  bool reconnectScheduled = false;
  int _retrySeconds;
  Stream<Message> _stream;
  Queue<Message> _messages = new Queue();
  Queue<Message> _responses = new Queue();

  MsgCache _sentMessages = new MsgCache();

  String sesId;

  static Function handler;

  bool get sockRdy => (_ws?.readyState == WebSocket.OPEN); //is websocket ready
  //bool readySnd = true; //Result is received and ready to send new message
  //bool get ready => (sockRdy && readySnd); //Everything is ready
  bool get connecting => (_ws?.readyState != WebSocket.CONNECTING);

  //bool readyRcv = true; // Ready to send response
  //bool get readyR => (sockRdy && readyRcv); //Everything is ready for response

  static Function logError = print;
  static Function logData = print;

  void scheduleReconnect() {
    if (!reconnectScheduled) {
      new Timer(new Duration(seconds: _retrySeconds), () => initWebSocket(_retrySeconds * 2));
    }
    reconnectScheduled = true;
  }

  void defaultHandler(Message msg) {
    /* execCommand(String cmd, Map pData, Fucntion callBack) */
    handler = MessageHandler.execCommand;
    //Call default handler and return response to message
    if (handler != null) handler(msg.pth, msg.msg, ((res) => _responses.add(new Message(res, msg.pth, null, id:msg.id))));
  }

  void sendEl() {
    //Schedule sending for later if queue is not empty
    if ((!sockRdy) && (!connecting)) {
      initWebSocket(); //if socket is not ready and not connecting now reInit websocket
      return;
    }

    if (sockRdy) {
      // If stream is ready send element
      if (_messages.length > 0) {
        Message cMsg = _messages.first; //Get first element from queue
        _messages.removeFirst(); //Remove first element from queue
        _ws.send(JSON.encode(cMsg)); //Send current element
        _sentMessages.setMsg(cMsg); //Save current message to sent map
        //readySnd = false; //Set ready to send No
      }
    }

    if (sockRdy) {
      //Ready to send response
      if (_responses.length > 0) {
        Message cResp = _responses.first; //Get first element from queue
        _responses.removeFirst(); //Remove first element from queue
        _ws.send(JSON.encode(cResp)); //Send current element
        //readyRcv = false; //Set ready to respond No
      }
    }
  }

  void sendAuth() {
    if ((sesId ?? "").length > 0) {
      _messages.addFirst(new Message({"sesid": sesId}, "auth", null));
      sendEl();
    }
  }

  void initWebSocket([int retrySeconds = 2]) {
    _ws = new WebSocket(_WSPath);
    if (_ws == null) {
      logError("Error openning websocket! $_WSPath");
      scheduleReconnect();
    } else {
      _retrySeconds = retrySeconds;

      _ws?.onOpen.listen((e) {
        reconnectScheduled = false; //Disable automtic recconnect on opened port
        sendAuth(); //Send authentification
      });

      _ws?.onClose.listen((e) {
        logData("WebSocket closed, retrying in $_retrySeconds seconds");
        scheduleReconnect();
      });

      _ws?.onError.listen((e) {
        logError("Error connecting to WebSocket");
        scheduleReconnect();
      });

      _ws?.onMessage.listen((MessageEvent e) {
        Message rMsg = new Message.fromJson(e.data); //Assemble returning message
        //logData("CMessage: $_cMsg Message:$rMsg");
        Message cMsg = _sentMessages.findMsg(rMsg);
        if (cMsg != null) {
          if (cMsg.handler != null) cMsg.handler(rMsg.msg); //This is answer for the current message
          //readySnd = true; //Ready to send Yes
          _sentMessages.remove(cMsg.id); //Remove finished element
          sendEl(); //Send next element
        } else {
          //readySnd flag will not be set current send is waiting!
          //readyRcv = true; // Ready to send next response
          defaultHandler(rMsg); //ready to send must be true if result for current query is received
        }
      });
    }

  }

  WSCarrier (this._WSPath, this.sesId, this._stream) {
    if (_WSPath != null) initWebSocket();
    //Init stream listening
    _stream.listen((msg) {
      _messages.add(msg); //add to messages queue
      if (sockRdy) sendEl(); // if socket is ready start sending
    });
  }
}

class WSClient {
  WSCarrier _wscarrier;
  String get sesid => _wscarrier.sesId;
  set sesid(String id) {
    if (_wscarrier.sesId != id) {
      _wscarrier.sesId = id;
      _wscarrier.sendAuth();
    }
  }

  set WSPath(String pth) => _wscarrier.WSPath = pth;

  bool get ready => _wscarrier.sockRdy;
  //set ready(bool rd) => (_wscarrier.readySnd = rd);

  StreamController<Message> _controller = new StreamController();

  //Add Message to stream
  void sendMessageCB(String pth, dynamic msg, Function handler, {int id}) => _controller.add(new Message(msg, pth, handler, id:id));
  Future sendMessage(String pth, dynamic msg, {int id}) { //Convert callback function to Future
    Completer comp = new Completer();
    sendMessageCB(pth, msg, ((res) => comp.complete(res)), id:id);
    return comp.future;
  }


  WSClient (String WSPath, String sesId) {
    _wscarrier = new WSCarrier(WSPath, sesId, _controller.stream);
   }


}

