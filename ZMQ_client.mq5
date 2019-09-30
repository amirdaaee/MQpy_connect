//+------------------------------------------------------------------+
//|                                                          ZMQ_client.mq5 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property tester_library "libzmq.dll"
#property tester_library "libsodium.dll"

#include <Zmq/Zmq.mqh>
#include <OnNewBar.mqh>
#include <JAson.mqh>

input string PROJECT_NAME="ZMQ_client";
input string ZEROMQ_PROTOCOL="tcp";
input string HOSTNAME="127.0.0.1";
input int PORT=5556;
input int MILLISECOND_TIMER=1;
input int PULLTIMEOUT=500;
input int LASTBARSCOUNT=128;
input int MagicNumber=123456;

Context context(PROJECT_NAME);
Socket socket(context,ZMQ_REQ);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
template<typename T>
T StringToEnum(string str,T enu)
  {
   for(int i=0;i<256;i++)
      if(EnumToString(enu=(T)i)==str)
         return(enu);
   return((T)NULL);
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- socket connection
   socket.connect(StringFormat("%s://%s:%d",ZEROMQ_PROTOCOL,HOSTNAME,PORT));
   context.setBlocky(false);
//---------------------------------------
//--- create timer
   EventSetTimer(MILLISECOND_TIMER);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();

//--- Shutdown ZeroMQ Context
   context.shutdown();
   Print("ZMQ context shutdown");
   context.destroy(0);
   Print("ZMQ context destroy");

  }
//+------------------------------------------------------------------+
//| bar handler                                             |
//+------------------------------------------------------------------+
void OnNewBar()
  {
   EventKillTimer();
   CJAVal req_json;
   req_json["event"]="newbar";
   req_json["state"]["symbol"]=Symbol();
//--- getting current status
   GetOpenOrders(req_json);
   GetOpenPositions(req_json);
//--- getting last bars
   GetLastBars(req_json);
//--- sending bars data to server
   string req_context="";
   req_json.Serialize(req_context);
   ZmqMsg request(req_context);
   Print("OnNewBar event to server");
   socket.send(request);
//--- getting server response
   GetResponse();
   EventSetTimer(MILLISECOND_TIMER);
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   CJAVal req_json;
   req_json["event"]="listen";
   req_json["state"]["symbol"]=Symbol();
//--- getting current status
   GetOpenOrders(req_json);
   GetOpenPositions(req_json);
//--- sending bars data to server
   string req_context="";
   req_json.Serialize(req_context);
   ZmqMsg request(req_context);
   socket.send(request);
//--- getting server response
   GetResponse();
  }
//+------------------------------------------------------------------+
//| Data To Server                                                    |
//+------------------------------------------------------------------+
void GetLastBars(CJAVal &js_ret)
  {
   MqlRates rates_array[];
   int rates_count=CopyRates(Symbol(),Period(),1,LASTBARSCOUNT,rates_array);
   if(rates_count>0)
     {
      for(int i=0; i<rates_count; i++)
        {
         js_ret["state"]["data"][i]["date"]=TimeToString(rates_array[i].time);
         js_ret["state"]["data"][i]["open"]=DoubleToString(rates_array[i].open);
         js_ret["state"]["data"][i]["high"]=DoubleToString(rates_array[i].high);
         js_ret["state"]["data"][i]["low"]=DoubleToString(rates_array[i].low);
         js_ret["state"]["data"][i]["close"]=DoubleToString(rates_array[i].close);
         js_ret["state"]["data"][i]["tick_volume"]=DoubleToString(rates_array[i].tick_volume);
         js_ret["state"]["data"][i]["real_volume"]=DoubleToString(rates_array[i].real_volume);
         js_ret["state"]["data"][i]["spread"]=DoubleToString(rates_array[i].spread);
        }
     }
   else
     {
      js_ret["state"]["data"]="null";
     }
  }
//+------------------------------------------------------------------+
void GetOpenPositions(CJAVal &js_ret)
  {
   int c=0;
   for(int i=0;i<PositionsTotal();i++)
     {
      if((PositionSelectByTicket(PositionGetTicket(i))) && (PositionGetString(POSITION_SYMBOL)==Symbol()))
        {
         js_ret["state"]["position"][c]["ticket"]=IntegerToString(PositionGetInteger(POSITION_TICKET));
         js_ret["state"]["position"][c]["identifier"]=IntegerToString(PositionGetInteger(POSITION_IDENTIFIER));
         js_ret["state"]["position"][c]["time"]=TimeToString(PositionGetInteger(POSITION_TIME));
         js_ret["state"]["position"][c]["type"]=EnumToString(ENUM_POSITION_TYPE(PositionGetInteger(POSITION_TYPE)));
         js_ret["state"]["position"][c]["volume"]=DoubleToString(PositionGetDouble(POSITION_VOLUME));
         js_ret["state"]["position"][c]["open"]=DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN));
         js_ret["state"]["position"][c]["price"]= DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT));
         js_ret["state"]["position"][c]["swap"] = DoubleToString(PositionGetDouble(POSITION_SWAP));
         js_ret["state"]["position"][c]["profit"]=DoubleToString(PositionGetDouble(POSITION_PROFIT));
         js_ret["state"]["position"][c]["sl"] = DoubleToString(PositionGetDouble(POSITION_SL));
         js_ret["state"]["position"][c]["tp"] = DoubleToString(PositionGetDouble(POSITION_TP));
         c++;
        }
     }
   if(c==0)
     {
      js_ret["state"]["position"]="null";
     }
  }
//+------------------------------------------------------------------+
void GetOpenOrders(CJAVal &js_ret)
  {
   int c=0;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(OrderGetTicket(i)) && (OrderGetString(ORDER_SYMBOL)==Symbol()))
        {
         js_ret["state"]["order"][c]["ticket"]=IntegerToString(OrderGetInteger(ORDER_TICKET));
         js_ret["state"]["order"][c]["time"]=TimeToString(OrderGetInteger(ORDER_TIME_SETUP));
         js_ret["state"]["order"][c]["type"]=EnumToString(ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE)));
         js_ret["state"]["order"][c]["state"]=EnumToString(ENUM_ORDER_STATE(OrderGetInteger(ORDER_STATE)));
         js_ret["state"]["order"][c]["lifetime"]=EnumToString(ENUM_ORDER_TYPE_TIME(OrderGetInteger(ORDER_TYPE_TIME)));
         js_ret["state"]["order"][c]["expiration"]=TimeToString(OrderGetInteger(ORDER_TIME_EXPIRATION));
         js_ret["state"]["order"][c]["volume"]=DoubleToString(OrderGetDouble(ORDER_VOLUME_CURRENT));
         js_ret["state"]["order"][c]["price"]=DoubleToString(OrderGetDouble(ORDER_PRICE_CURRENT));
         js_ret["state"]["order"][c]["sl"]=DoubleToString(OrderGetDouble(ORDER_SL));
         js_ret["state"]["order"][c]["tp"]=DoubleToString(OrderGetDouble(ORDER_TP));
         c++;
        }
     }
   if(c==0)
     {
      js_ret["state"]["order"]="null";
     }
  }
//+------------------------------------------------------------------+
//| Data From Server                                                |
//+------------------------------------------------------------------+
void GetResponse()
  {
   CJAVal resp_json;
   ZmqMsg message;
   PollItem items[1];
   socket.fillPollItem(items[0],ZMQ_POLLIN);
   Socket::poll(items,PULLTIMEOUT);
// empty response handler
   if(items[0].hasInput())
     {
      socket.recv(message);
      resp_json.Deserialize(message.getData());
      WhichAction(resp_json);
     }
   else{Print("empty response from server");}
  }
//+------------------------------------------------------------------+
void WhichAction(CJAVal &resp_json)
  {
   string command=resp_json["command"].ToStr();
   if(command=="position_open")
     {PositionOpen(&resp_json);}
   else if(command=="position_modify")
     {PositionModify(&resp_json);}
   else if(command=="position_close")
     {PositionClose(&resp_json);}
   else if(command=="resume")
     {return;}
   else if(command=="error")
     {Print("server side error");}
   else
     {Print("command not understood");}
  }
//+------------------------------------------------------------------+
//| Action                                                                  |
//+------------------------------------------------------------------+
void PositionOpen(CJAVal &resp_json)
  {
   Print("New order request");
   MqlTradeRequest MTrequest;
   MqlTradeResult  MTresult;
// fulfill default
   MTrequest.symbol=Symbol();
   MTrequest.magic=MagicNumber;
   MTrequest.comment=NULL;
   MTrequest.position=NULL;
   MTrequest.position_by=NULL;
// fulfill from response
   ENUM_TRADE_REQUEST_ACTIONS action=TRADE_ACTION_DEAL;
   ENUM_ORDER_TYPE  type=ORDER_TYPE_BUY;
   ENUM_ORDER_TYPE_FILLING type_filling=NULL;
   ENUM_ORDER_TYPE_TIME type_time=NULL;

   MTrequest.action=StringToEnum(resp_json["args"]["action"].ToStr(),action);
   MTrequest.type=StringToEnum(resp_json["args"]["type"].ToStr(),type);
   MTrequest.type_filling=StringToEnum(resp_json["args"]["type_filling"].ToStr(),type_filling);
   MTrequest.type_time=StringToEnum(resp_json["args"]["type_time"].ToStr(),type_time);
   MTrequest.volume=resp_json["args"]["volume"].ToDbl();
   MTrequest.price=resp_json["args"]["price"].ToDbl();
   MTrequest.stoplimit=resp_json["args"]["stoplimit"].ToDbl();
   MTrequest.deviation=resp_json["args"]["deviation"].ToInt();
   MTrequest.sl= resp_json["args"]["sl"].ToDbl();
   MTrequest.tp= resp_json["args"]["tp"].ToDbl();
   MTrequest.expiration=StringToTime(resp_json["args"]["expiration"].ToStr());
// order allocation
   bool status=OrderSend(MTrequest,MTresult);
   if(status==true)
     {
      Print("New order : Done");
     }
   else
     {
      Print("New order : Fail");
     }
   PrintFormat("broker return code : %d",MTresult.retcode);
  }
//+------------------------------------------------------------------+
void PositionModify(CJAVal &resp_json)
  {
   Print("Position modify request");
   MqlTradeRequest MTrequest;
   MqlTradeResult  MTresult;
// fulfill default
   MTrequest.action=TRADE_ACTION_SLTP;
   MTrequest.symbol=Symbol();
   MTrequest.magic=MagicNumber;
   MTrequest.deviation=NULL;
   MTrequest.comment=NULL;
   MTrequest.position_by=NULL;
   MTrequest.type=NULL;
   MTrequest.type_filling=NULL;
   MTrequest.type_time=NULL;
   MTrequest.volume=NULL;
   MTrequest.price=NULL;
   MTrequest.stoplimit=NULL;
   MTrequest.expiration=NULL;

   for(int i=0;i<resp_json["args"]["ticket"].Size();i++)
     {
      // fulfill from response
      MTrequest.position=resp_json["args"]["ticket"][i].ToInt();
      MTrequest.sl= resp_json["args"]["sl"][i].ToDbl();
      MTrequest.tp= resp_json["args"]["tp"][i].ToDbl();
      // order allocation
      bool status=OrderSend(MTrequest,MTresult);
      if(status==true)
        {
         PrintFormat("position modify(ticket:%u) : Done",resp_json["args"]["ticket"][i].ToInt());
        }
      else
        {
         PrintFormat("position modify(ticket:%u) : Fail",resp_json["args"]["ticket"][i].ToInt());
        }
      PrintFormat("broker return code : %d",MTresult.retcode);
     }

  }
//+------------------------------------------------------------------+
void PositionClose(CJAVal &resp_json)
  {
   Print("Position close request");
   MqlTradeRequest MTrequest;
   MqlTradeResult  MTresult;
// fulfill default
   MTrequest.action=TRADE_ACTION_DEAL;
   MTrequest.symbol=Symbol();
   MTrequest.magic=MagicNumber;
   MTrequest.deviation=NULL;
   MTrequest.sl=NULL;
   MTrequest.tp=NULL;
   MTrequest.comment=NULL;
   MTrequest.position_by=NULL;
   MTrequest.type_filling=NULL;
   MTrequest.type_time=NULL;
   MTrequest.price=NULL;
   MTrequest.stoplimit=NULL;
   MTrequest.expiration=NULL;

   for(int i=0;i<resp_json["args"]["ticket"].Size();i++)
     {
      // fulfill from response
      MTrequest.position=resp_json["args"]["ticket"][i].ToInt();
      // ---------- logical
      PositionSelectByTicket(resp_json["args"]["ticket"][i].ToInt());
      //
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         MTrequest.type=ORDER_TYPE_SELL;
        }
      else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
        {
         MTrequest.type=ORDER_TYPE_BUY;
        }
      //
      if((resp_json["args"]["volume"][i].ToDbl()<=0) || (PositionGetDouble(POSITION_VOLUME)<=resp_json["args"]["volume"][i].ToDbl()))
        {
         MTrequest.volume=PositionGetDouble(POSITION_VOLUME);
        }
      else
        {
         MTrequest.volume=resp_json["args"]["volume"][i].ToDbl();
        }
      // order allocation
      bool status=OrderSend(MTrequest,MTresult);
      if(status==true)
        {
         PrintFormat("position close(ticket:%u) : Done",resp_json["args"]["ticket"][i].ToInt());
        }
      else
        {
         PrintFormat("position close(ticket:%u) : Done",resp_json["args"]["ticket"][i].ToInt());
        }
      PrintFormat("broker return code : %d",MTresult.retcode);
     }
  }
//+------------------------------------------------------------------+
