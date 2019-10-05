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

string PROJECT_NAME="ZMQ_client";
input string HOSTNAME="127.0.0.1";
input int PORT=5556;
input string ZEROMQ_PROTOCOL="tcp";
//input bool ONTIMEREVENT=false;
//input int MILLISECOND_TIMER=1;
input int PULLTIMEOUT=500;
input int LASTBARSCOUNT=64;
input int MagicNumber=123456;

Context context(PROJECT_NAME);
Socket socket(context,ZMQ_REQ);
//+------------------------------------------------------------------+
//|
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
//| Expert initialization function
//+------------------------------------------------------------------+
int OnInit()
  {
//--- socket connection
   socket.connect(StringFormat("%s://%s:%d",ZEROMQ_PROTOCOL,HOSTNAME,PORT));
   context.setBlocky(false);
//--- send init request to server   
   CJAVal req_json;
   req_json["event"]="init";
   req_json["args"]["symbol"]=Symbol();
   req_json["args"]["magic"]=MagicNumber;
   GetOpenOrders(req_json);
   GetOpenPositions(req_json);
   SendRequest(req_json);
//---------------------------------------
//--- create timer
//EventSetTimer(MILLISECOND_TIMER);

   Print("initialization success");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
//EventKillTimer();
//--- send deinit request to server
   CJAVal req_json;
   req_json["event"]="deinit";
   req_json["args"]["magic"]=MagicNumber;
   SendRequest(req_json);
//--- Shutdown ZeroMQ Context
   context.shutdown();
   Print("ZMQ context shutdown");
   context.destroy(0);
   Print("ZMQ context destroy");
  }
//+------------------------------------------------------------------+
//| events handler
//+------------------------------------------------------------------+
void OnTrade()
  {
   CJAVal req_json;
   req_json["event"]="newtrade";
   GetOpenOrders(req_json);
   GetOpenPositions(req_json);
   SendRequest(req_json);
  }
//+------------------------------------------------------------------+
void OnNewBar()
  {
   CJAVal req_json;
   req_json["event"]="newbar";
   GetLastBars(req_json);
   SendRequest(req_json);
  }
//+------------------------------------------------------------------+
//| Request fullfil
//| *** all data for current symbol only
//+------------------------------------------------------------------+
void GetOpenOrders(CJAVal &js_ret)
  {
   int c=0;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(OrderGetTicket(i)) && (OrderGetString(ORDER_SYMBOL)==Symbol()))
        {
         js_ret["args"]["order"][c]["TICKET"]=IntegerToString(OrderGetInteger(ORDER_TICKET));
         js_ret["args"]["order"][c]["TIME_SETUP"]=TimeToString(OrderGetInteger(ORDER_TIME_SETUP));
         js_ret["args"]["order"][c]["TYPE"]=EnumToString(ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE)));
         js_ret["args"]["order"][c]["STATE"]=EnumToString(ENUM_ORDER_STATE(OrderGetInteger(ORDER_STATE)));
         js_ret["args"]["order"][c]["TIME_EXPIRATION"]=TimeToString(OrderGetInteger(ORDER_TIME_EXPIRATION));
         js_ret["args"]["order"][c]["TYPE_FILLING"]=EnumToString(ENUM_ORDER_TYPE_FILLING(OrderGetInteger(ORDER_TYPE_FILLING)));
         js_ret["args"]["order"][c]["TYPE_TIME"]=EnumToString(ENUM_ORDER_TYPE_TIME(OrderGetInteger(ORDER_TYPE_TIME)));
         js_ret["args"]["order"][c]["MAGIC"]=IntegerToString(OrderGetInteger(ORDER_MAGIC));
         js_ret["args"]["order"][c]["VOLUME_CURRENT"]=DoubleToString(OrderGetDouble(ORDER_VOLUME_CURRENT));
         js_ret["args"]["order"][c]["PRICE_OPEN"]=DoubleToString(OrderGetDouble(ORDER_PRICE_OPEN));
         js_ret["args"]["order"][c]["SL"]=DoubleToString(OrderGetDouble(ORDER_SL));
         js_ret["args"]["order"][c]["TP"]=DoubleToString(OrderGetDouble(ORDER_TP));
         js_ret["args"]["order"][c]["PRICE_STOPLIMIT"]=DoubleToString(OrderGetDouble(ORDER_PRICE_STOPLIMIT));
         c++;
        }
     }
   if(c==0)
     {
      js_ret["args"]["order"]="null";
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
         js_ret["args"]["position"][c]["TICKET"]=IntegerToString(PositionGetInteger(POSITION_TICKET));
         js_ret["args"]["position"][c]["TIME"]=TimeToString(PositionGetInteger(POSITION_TIME));
         js_ret["args"]["position"][c]["TYPE"]=EnumToString(ENUM_POSITION_TYPE(PositionGetInteger(POSITION_TYPE)));
         js_ret["args"]["position"][c]["MAGIC"]=IntegerToString(PositionGetInteger(POSITION_MAGIC));
         js_ret["args"]["position"][c]["IDENTIFIER"]=IntegerToString(PositionGetInteger(POSITION_IDENTIFIER));
         js_ret["args"]["position"][c]["VOLUME"]=DoubleToString(PositionGetDouble(POSITION_VOLUME));
         js_ret["args"]["position"][c]["PRICE_OPEN"]=DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN));
         js_ret["args"]["position"][c]["SL"] = DoubleToString(PositionGetDouble(POSITION_SL));
         js_ret["args"]["position"][c]["TP"] = DoubleToString(PositionGetDouble(POSITION_TP));
         js_ret["args"]["position"][c]["PRICE_CURRENT"]=DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT));
         js_ret["args"]["position"][c]["SWAP"]=DoubleToString(PositionGetDouble(POSITION_SWAP));
         js_ret["args"]["position"][c]["PROFIT"]=DoubleToString(PositionGetDouble(POSITION_PROFIT));

         c++;
        }
     }
   if(c==0)
     {
      js_ret["args"]["position"]="null";
     }
  }
//+------------------------------------------------------------------+
void GetLastBars(CJAVal &js_ret)
  {
   MqlRates rates_array[];
   int rates_count=CopyRates(Symbol(),Period(),1,LASTBARSCOUNT,rates_array);
   if(rates_count>0)
     {
      for(int i=0; i<rates_count; i++)
        {
         js_ret["args"]["data"][i]["date"]=TimeToString(rates_array[i].time);
         js_ret["args"]["data"][i]["open"]=DoubleToString(rates_array[i].open);
         js_ret["args"]["data"][i]["high"]=DoubleToString(rates_array[i].high);
         js_ret["args"]["data"][i]["low"]=DoubleToString(rates_array[i].low);
         js_ret["args"]["data"][i]["close"]=DoubleToString(rates_array[i].close);
         js_ret["args"]["data"][i]["tick_volume"]=DoubleToString(rates_array[i].tick_volume);
         js_ret["args"]["data"][i]["real_volume"]=DoubleToString(rates_array[i].real_volume);
         js_ret["args"]["data"][i]["spread"]=DoubleToString(rates_array[i].spread);
        }
     }
   else
     {
      js_ret["args"]["data"]="null";
     }
  }
//+------------------------------------------------------------------+
//| Requesting
//+------------------------------------------------------------------+
//--- sending bars data to server
void SendRequest(CJAVal &req_json)
  {
   req_json["magic"]=IntegerToString(MagicNumber);
   string req_context="";
   req_json.Serialize(req_context);
   ZmqMsg request(req_context);
   socket.send(request);
   GetResponse();
  }
//+------------------------------------------------------------------+
//| Response handle
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
//| Action
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
      PrintFormat("New order : Fail (%u)",MTresult.retcode);
     }
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
// fulfill from response
   for(int i=0;i<resp_json["args"]["ticket"].Size();i++)
     {
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
         PrintFormat("position modify(ticket:%u) : Fail (%u)",resp_json["args"]["ticket"][i].ToInt(),MTresult.retcode);
        }
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
// fulfill from response
   for(int i=0;i<resp_json["args"]["ticket"].Size();i++)
     {
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
         PrintFormat("position close(ticket:%u) : Done (%u)",resp_json["args"]["ticket"][i].ToInt(),MTresult.retcode);
        }
     }
  }
//+------------------------------------------------------------------+
