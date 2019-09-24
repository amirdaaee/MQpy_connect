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
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- socket connection
   socket.connect(StringFormat("%s://%s:%d",ZEROMQ_PROTOCOL,HOSTNAME,PORT));
   context.setBlocky(false);
//--- for development purpose
   OnNewBar();
//--- create timer
//EventSetTimer(MILLISECOND_TIMER);

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
// getting responce message from python server 
void GetResponce()
  {

   CJAVal resp_json;
   ZmqMsg message;
   PollItem items[1];
   socket.fillPollItem(items[0],ZMQ_POLLIN);
   Socket::poll(items,PULLTIMEOUT);
//--- parsing server's response data
   if(items[0].hasInput())
     {
      socket.recv(message);
      Print(message.getData());

      resp_json.Deserialize(message.getData());
      WhichAction(resp_json);

     }

  }
//parsing responce message and convert it to json format
/* void Convert_Responce_to_Json( string message )
 {
    CJAVal resp_json;
    
     resp_json.Deserialize(message);
     WhichAction(resp_json)
   
 
 }
  
  */

//+------------------------------------------------------------------+
//| Expert bar function                                             |
//+------------------------------------------------------------------+
void OnNewBar()
  {
   CJAVal req_json;
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
   ZmqMsg message;
   PollItem items[1];
   socket.fillPollItem(items[0],ZMQ_POLLIN);
   Socket::poll(items,PULLTIMEOUT);
//--- parsing server's response data
   if(items[0].hasInput())
     {
      socket.recv(message);
      Print(message.getData());
     }

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
//--- Get prices
   MqlRates rates_array[];
   int rates_count=CopyRates(Symbol(),Period(),1,LASTBARSCOUNT,rates_array);
   if(rates_count>0)
     {
      //--- Construct string of rates and send to PULL client.
      for(int i=0; i<rates_count; i++)
        {
         js_ret["data"][i]["date"]=TimeToString(rates_array[i].time);
         js_ret["data"][i]["open"]=DoubleToString(rates_array[i].open);
         js_ret["data"][i]["high"]=DoubleToString(rates_array[i].high);
         js_ret["data"][i]["low"]=DoubleToString(rates_array[i].low);
         js_ret["data"][i]["close"]=DoubleToString(rates_array[i].close);
         js_ret["data"][i]["tick_volume"]=DoubleToString(rates_array[i].tick_volume);
         js_ret["data"][i]["real_volume"]=DoubleToString(rates_array[i].real_volume);
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
//--- Get Open Positions
   if(PositionSelect(Symbol()))
     {
      js_ret["position"]["ticket"]=IntegerToString(PositionGetInteger(POSITION_TICKET));
      js_ret["position"]["identifier"]=IntegerToString(PositionGetInteger(POSITION_IDENTIFIER));
      js_ret["position"]["time"]=TimeToString(PositionGetInteger(POSITION_TIME));
      js_ret["position"]["type"]=IntegerToString(PositionGetInteger(POSITION_TYPE));
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
//--- Get Open Orders of current chart only
   int c1=0;
   for(int c=0;c<OrdersTotal();c++)
     {
      ulong ticket=OrderGetTicket(c);
      if(OrderSelect(ticket) && (OrderGetString(ORDER_SYMBOL)==Symbol()))
        {
         js_ret["order"][c1]["ticket"]=IntegerToString(OrderGetInteger(ORDER_TICKET));
         js_ret["order"][c1]["time"]=TimeToString(OrderGetInteger(ORDER_TIME_SETUP));
         js_ret["order"][c1]["type"]=IntegerToString(OrderGetInteger(ORDER_TYPE));
         js_ret["order"][c1]["expiration"]=TimeToString(OrderGetInteger(ORDER_TIME_EXPIRATION));
         js_ret["order"][c1]["volume"]=DoubleToString(OrderGetDouble(ORDER_VOLUME_CURRENT));
         js_ret["order"][c1]["price"]=DoubleToString(OrderGetDouble(ORDER_PRICE_CURRENT));
         js_ret["order"][c1]["sl"]=DoubleToString(OrderGetDouble(ORDER_SL));
         js_ret["order"][c1]["tp"]=DoubleToString(OrderGetDouble(ORDER_TP));
         c1++;
        }
     }
   Print(c1);
   if(c1==0)
     {
      js_ret["order"]="NULL";
     }
  }
//+------------------------------------------------------------------+

void WhichAction(CJAVal &resp_json)
  {
   if(resp_json["command"].ToStr()=="new_order")
     {
      New_Order_Requset(&resp_json);
     }

   else if(resp_json["command"].ToStr()=="resume")
     {
      Print("resume");
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void New_Order_Requset(CJAVal &resp_json)
  {
   MqlTradeRequest MTrequest={0};
   MqlTradeResult  MTresult={0};

   ENUM_TRADE_REQUEST_ACTIONS  TRADE_REQUEST_ACTIONS=resp_json["args"]["action"].ToStr();
   MTrequest.action=TRADE_REQUEST_ACTIONS;
/*
   if(resp_json["args"]["action"].ToStr()=="TRADE_ACTION_DEAL")
     {
      MTrequest.action=TRADE_ACTION_DEAL;
     }

   else if(resp_json["args"]["action"].ToStr()=="TRADE_ACTION_DEAL")
     {
      MTrequest.action=TRADE_ACTION_DEAL;

     }
     */

   ENUM_ORDER_TYPE ORDER_TYPE=resp_json["args"]["type"].ToStr();
   MTrequest.type=ORDER_TYPE;
/*

   if(resp_json["args"]["type"].ToStr()=="ORDER_TYPE_BUY")
     {
      MTrequest.type=ORDER_TYPE_BUY;
     }

   else if(resp_json["args"]["type"].ToStr()=="ORDER_TYPE_SELL")
     {
      MTrequest.type=ORDER_TYPE_SELL;
     }

   else if(resp_json["args"]["type"].ToStr()=="ORDER_TYPE_BUY_LIMIT")
     {
      MTrequest.type=ORDER_TYPE_BUY_LIMIT;
     }

   else if(resp_json["args"]["type"].ToStr()=="ORDER_TYPE_SELL_LIMIT")
     {
      MTrequest.type=ORDER_TYPE_SELL_LIMIT;
     }
   else if(resp_json["args"]["type"].ToStr()=="ORDER_TYPE_BUY_STOP")
     {
      MTrequest.type=ORDER_TYPE_BUY_STOP;
     }
   else if(resp_json["args"]["type"].ToStr()=="ORDER_TYPE_SELL_STOP")
     {
      MTrequest.type=ORDER_TYPE_SELL_STOP;
     }
   else if(resp_json["args"]["type"].ToStr()=="ORDER_TYPE_BUY_STOP_LIMIT")
     {
      MTrequest.type=ORDER_TYPE_BUY_STOP_LIMIT;
     }
   else if(resp_json["args"]["type"].ToStr()=="ORDER_TYPE_SELL_STOP_LIMIT")
     {
      MTrequest.type=ORDER_TYPE_SELL_STOP_LIMIT;
     }

   else
     {
      MTrequest.type=NULL;
     }
     
     */

   ENUM_ORDER_TYPE_FILLING  ORDER_TYPE_FILLING=resp_json["args"]["type_filling"].ToStr();
   MTrequest.type_filling=ORDER_TYPE_FILLING;

/*if(resp_json["args"]["type_filling"].ToStr()=="ORDER_FILLING_FOK")
     {
      MTrequest.type_filling=ORDER_FILLING_FOK;
     }

   else if(resp_json["args"]["type_filling"].ToStr()=="ORDER_FILLING_IOC")
     {
      MTrequest.type_filling=ORDER_FILLING_IOC;
     }
     
    */


   ENUM_ORDER_TYPE_TIME ORDER_TYPE_TIME=resp_json["args"]["type_time"].ToStr();
   MTrequest.type_time=ORDER_TYPE_TIME;

/*  if(resp_json["args"]["type_time"].ToStr()=="ORDER_TIME_GTC")
     {
      MTrequest.type_time=ORDER_TIME_GTC;
     }

   else if(resp_json["args"]["type_time"].ToStr()=="ORDER_TIME_DAY")
     {
      MTrequest.type_time=ORDER_TIME_DAY;
     }

   else if(resp_json["args"]["type_time"].ToStr()=="ORDER_TIME_SPECIFIED")
     {
      MTrequest.type_time=ORDER_TIME_SPECIFIED;
     }
     
     */

// type of trade operation
   MTrequest.symbol=Symbol();                                         // symbol
   MTrequest.volume= resp_json["args"]["volume"].ToDbl();             // volume of 0.1 lot

                                                                      // MTrequest.price     = SymbolInfoDouble(Symbol(),SYMBOL_ASK);

   MTrequest.price=resp_json["args"]["price"].ToDbl();             // price for opening
   MTrequest.magic      = MagicNumber;
   MTrequest.stoplimit  = resp_json["args"]["stoplimit"].ToDbl();
   MTrequest.sl         = resp_json["args"]["sl"].ToDbl();
   MTrequest.tp         = resp_json["args"]["tp"].ToDbl();
   string expiration    = resp_json["args"]["expiration"].ToStr();
   MTrequest.expiration = StringToTime(expiration);

   OrderSend(MTrequest,MTresult);

  }
//+------------------------------------------------------------------+
