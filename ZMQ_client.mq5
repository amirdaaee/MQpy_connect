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
//--- getting last bars 
   string s=GetLastBars();
//--- sending bars data to server
   ZmqMsg request(s);
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
string GetLastBars()
  {
   string zmq_ret;
   MqlRates rates_array[];

//--- Get prices
   int rates_count=CopyRates(NULL,NULL,1,LASTBARSCOUNT,rates_array);
   if(rates_count>0)
     {
      zmq_ret=zmq_ret+" 'data': [";

      //--- Construct string of rates and send to PULL client.
      for(int i=0; i<rates_count; i++)
        {
         if(i==0)
            zmq_ret=zmq_ret+"{'time':'"+TimeToString(rates_array[i].time)+"', 'open':"+DoubleToString(rates_array[i].open)+", 'high':"+DoubleToString(rates_array[i].high)+", 'low':"+DoubleToString(rates_array[i].low)+", 'close':"+DoubleToString(rates_array[i].close)+", 'tick_volume':"+IntegerToString(rates_array[i].tick_volume)+", 'spread':"+IntegerToString(rates_array[i].spread)+", 'real_volume':"+IntegerToString(rates_array[i].real_volume)+"}";
         else
            zmq_ret=zmq_ret+", {'time':'"+TimeToString(rates_array[i].time)+"', 'open':"+DoubleToString(rates_array[i].open)+", 'high':"+DoubleToString(rates_array[i].high)+", 'low':"+DoubleToString(rates_array[i].low)+", 'close':"+DoubleToString(rates_array[i].close)+", 'tick_volume':"+IntegerToString(rates_array[i].tick_volume)+", 'spread':"+IntegerToString(rates_array[i].spread)+", 'real_volume':"+IntegerToString(rates_array[i].real_volume)+"}";
        }
      zmq_ret=zmq_ret+"]";
     }
//------ if NO data then forms response as json:
//------ {'_action: 'HIST',
//------ '_response': 'NOT_AVAILABLE'
//------ }
   else
     {
      zmq_ret=zmq_ret+"'data': null";
     }
   return   zmq_ret;
  }
//+------------------------------------------------------------------+
