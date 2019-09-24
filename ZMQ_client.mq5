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
//---
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
//--------------------------------------- for development purpose
//OnNewBar();

   CJAVal test;
   test["command"]="order_new";
   test["args"]["action"]="TRADE_ACTION_DEAL";
   test["args"]["type"]="ORDER_TYPE_BUY";
   test["args"]["type_time"]="null";
   test["args"]["type_filling"]="ORDER_FILLING_FOK";
   test["args"]["volume"]="0.01";
   test["args"]["price"]="null";
   test["args"]["stoplimit"]="null";
   test["args"]["sl"]="null";
   test["args"]["tp"]="null";
   test["args"]["expiration"]="null";
   WhichAction(test);
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
//| Expert bar function                                             |
//+------------------------------------------------------------------+
void OnNewBar()
  {
   CJAVal req_json;
   req_json["event"] = "newbar";
   req_json["symbol"]=Symbol();
//--- getting current status
   GetOpenOrders(req_json);
   GetOpenPositions(req_json);
//--- getting last bars
   GetLastBars(req_json);
//--- sending bars data to server
   string req_context="";
   req_json.Serialize(req_context);
   ZmqMsg request(req_context);
   Print("last bars data to server");
   socket.send(request);
//--- getting server response
   GetResponse();
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---

  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
//---

  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
  {
//---

  }
//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
  {
//---

  }
//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
//---

  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---

  }
//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
//---

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
         js_ret["data"][i]["date"]=TimeToString(rates_array[i].time);
         js_ret["data"][i]["open"]=DoubleToString(rates_array[i].open);
         js_ret["data"][i]["high"]=DoubleToString(rates_array[i].high);
         js_ret["data"][i]["low"]=DoubleToString(rates_array[i].low);
         js_ret["data"][i]["close"]=DoubleToString(rates_array[i].close);
         js_ret["data"][i]["tick_volume"]=DoubleToString(rates_array[i].tick_volume);
         js_ret["data"][i]["real_volume"]=DoubleToString(rates_array[i].real_volume);
         js_ret["data"][i]["spread"]=DoubleToString(rates_array[i].spread);
        }
     }
   else
     {
      js_ret["data"]="NULL";
     }
  }
//+------------------------------------------------------------------+
void GetOpenPositions(CJAVal &js_ret)
  {
   if(PositionSelect(Symbol()))
     {
      js_ret["position"]["ticket"]=IntegerToString(PositionGetInteger(POSITION_TICKET));
      js_ret["position"]["identifier"]=IntegerToString(PositionGetInteger(POSITION_IDENTIFIER));
      js_ret["position"]["time"]=TimeToString(PositionGetInteger(POSITION_TIME));
      js_ret["position"]["type"]=EnumToString(ENUM_POSITION_TYPE(PositionGetInteger(POSITION_TYPE)));
      js_ret["position"]["volume"]=DoubleToString(PositionGetDouble(POSITION_VOLUME));
      js_ret["position"]["open"]=DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN));
      js_ret["position"]["price"]= DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT));
      js_ret["position"]["swap"] = DoubleToString(PositionGetDouble(POSITION_SWAP));
      js_ret["position"]["profit"]=DoubleToString(PositionGetDouble(POSITION_PROFIT));
      js_ret["position"]["sl"] = DoubleToString(PositionGetDouble(POSITION_SL));
      js_ret["position"]["tp"] = DoubleToString(PositionGetDouble(POSITION_TP));
     }
   else
     {
      js_ret["position"]="NULL";
     }
  }
//+------------------------------------------------------------------+
void GetOpenOrders(CJAVal &js_ret)
  {
   int c1=0;
   for(int c=0;c<OrdersTotal();c++)
     {
      ulong ticket=OrderGetTicket(c);
      if(OrderSelect(ticket) && (OrderGetString(ORDER_SYMBOL)==Symbol()))
        {
         js_ret["order"][c1]["ticket"]=IntegerToString(OrderGetInteger(ORDER_TICKET));
         js_ret["order"][c1]["time"]=TimeToString(OrderGetInteger(ORDER_TIME_SETUP));
         js_ret["order"][c1]["type"]=EnumToString(ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE)));
         js_ret["order"][c1]["state"]=EnumToString(ENUM_ORDER_STATE(OrderGetInteger(ORDER_STATE)));
         js_ret["order"][c1]["lifetime"]=EnumToString(ENUM_ORDER_TYPE_TIME(OrderGetInteger(ORDER_TYPE_TIME)));
         js_ret["order"][c1]["expiration"]=TimeToString(OrderGetInteger(ORDER_TIME_EXPIRATION));
         js_ret["order"][c1]["volume"]=DoubleToString(OrderGetDouble(ORDER_VOLUME_CURRENT));
         js_ret["order"][c1]["price"]=DoubleToString(OrderGetDouble(ORDER_PRICE_CURRENT));
         js_ret["order"][c1]["sl"]=DoubleToString(OrderGetDouble(ORDER_SL));
         js_ret["order"][c1]["tp"]=DoubleToString(OrderGetDouble(ORDER_TP));
         c1++;
        }
     }
   if(c1==0)
     {
      js_ret["order"]="NULL";
     }
  }
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
      Print(message.getData());
      resp_json.Deserialize(message.getData());
      WhichAction(resp_json);
     }
   else{Print("empty response from server");}
  }
//+------------------------------------------------------------------+
void WhichAction(CJAVal &resp_json)
  {
   if(resp_json["command"].ToStr()=="order_new")
     {
      NewOrder(&resp_json);
     }
   else if(resp_json["command"].ToStr()=="resume")
     {
      Print("resume");
     }
  }
//+------------------------------------------------------------------+
void NewOrder(CJAVal &resp_json)
  {
   Print("New order request");
   MqlTradeRequest MTrequest={0};
   MqlTradeResult  MTresult;
// fulfill default
   MTrequest.symbol=Symbol();
   MTrequest.magic=MagicNumber;
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
   MTrequest.sl= resp_json["args"]["sl"].ToDbl();
   MTrequest.tp= resp_json["args"]["tp"].ToDbl();
   MTrequest.expiration=StringToTime(resp_json["args"]["expiration"].ToStr());

// order allocation
   bool status=OrderSend(MTrequest,MTresult);
   if(status==true)
     {
      Print("Done");
     }
   else
     {
      Print("Fail");
     }
   PrintFormat("broker return code : %d",MTresult.retcode);
  }
//+------------------------------------------------------------------+
