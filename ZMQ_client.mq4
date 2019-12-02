//+------------------------------------------------------------------+
//|                                                           AI.mq4 |
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
input int PULLTIMEOUT=500;
input int LASTBARSCOUNT=48;
input int MagicNumber=123456;
const string Version = "MT4";
string ServerLastMsg = "";

//todo:optional timer event
//+------------------------------------------------------------------+
Context context(PROJECT_NAME);
Socket socket(context,ZMQ_REQ);
//+------------------------------------------------------------------+
template<typename T>
T StringToEnum(string str,T enu)
{
	for(int i=0; i<256; i++)
	{
		if(EnumToString(enu=(T)i)==str)
		{
			return(enu);
		}
		return((T)NULL);
	}
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
   req_json["args"]["version"]=Version;
   req_json["args"]["magic"]=MagicNumber;
   GetOpenOrders(req_json);
   GetOpenPositions(req_json);
   SendRequest(req_json);
//--- create timer
//    EventSetTimer(MILLISECOND_TIMER);
   Print("initialization success");
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function
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
	for(int i=0; i<OrdersTotal(); i++)
	{
		if(OrderSelect(i,SELECT_BY_TICKET,MODE_TRADES) && (OrderGetString(ORDER_SYMBOL)==Symbol()))
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
   for(int i=0; i<PositionsTotal(); i++)
	{
      if((OrderSelect(PositionGetTicket(i),SELECT_BY_TICKET,MODE_TRADES)))
		{
         js_ret["args"]["position"][c]["TICKET"]=IntegerToString(OrderTicket());
         js_ret["args"]["position"][c]["TYPE"]=OrderType();
         js_ret["args"]["position"][c]["MAGIC"]=IntegerToString(OrderMagicNumber());
         //         js_ret["args"]["position"][c]["IDENTIFIER"]=IntegerToString(PositionGetInteger(POSITION_IDENTIFIER));
         js_ret["args"]["position"][c]["VOLUME"]=DoubleToString(OrderLots());
         js_ret["args"]["position"][c]["PRICE_OPEN"]=DoubleToString(OrderOpenPrice());
         js_ret["args"]["position"][c]["SL"] = DoubleToString(OrderStopLoss());
         js_ret["args"]["position"][c]["TP"] = DoubleToString(OrderTakeProfit());
         js_ret["args"]["position"][c]["PROFIT"]=DoubleToString(OrderProfit());
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
//--- empty response handler
   if(items[0].hasInput())
	{
      socket.recv(message);
      resp_json.Deserialize(message.getData());
      ResponseParse(resp_json);
	}
   else
	{
      Print("empty response from server");
	}
}
//+------------------------------------------------------------------+
void ResponseParse(CJAVal &resp_json)
{
	string resptype = resp_json["type"].ToStr();
	if(resptype=="action")
	{
		WhichAction(resp_json);
	}
	else if(resptype=="message")
	{

	}

}
//+------------------------------------------------------------------+
void WhichAction(CJAVal &resp_json)
{
   string command=resp_json["command"].ToStr();
   if(command=="position_open")
   	{
      PositionOpen(resp_json);
		}
   /*   else
         if(command=="position_modify")
            PositionModify(&resp_json);
   */
   else if(command=="position_close")
	{
		PositionClose(resp_json);
	}
	else
	{
		Print("command not understood");
	}
}
//+------------------------------------------------------------------+
//| Action
//+------------------------------------------------------------------+
void PositionOpen(CJAVal &resp_json)
{
   Print("New order request");
   double price=0;
   enum type
	{
      B=OP_BUY,// Buy Position
      S=OP_SELL,// Sell Position
      D,
	};
   color OrderColor=clrWhite;
   type X;
// fulfill from response
   X=StringToEnum(resp_json["args"]["type"].ToStr(),D);
   double volume=resp_json["args"]["volume"].ToDbl();
   double sl= resp_json["args"]["sl"].ToDbl();
   double tp= resp_json["args"]["tp"].ToDbl();
   if(X == S)
	{
      OrderColor = clrRed;
      price= Bid;
	}
   else
      if(X == B)
        {
         OrderColor = clrGreen;
         price= Ask;
        }
   bool status = OrderSend(Symbol(), X, volume, price, 100, sl, tp, "Strategy AI", MagicNumber, 0, OrderColor) ;
   if(status==true)
     {
      Print("New order : Done");
     }
   else
     {
      PrintFormat("New order : Fail (%u)");
     }
  }
//+------------------------------------------------------------------+
/*
void PositionModify(CJAVal &resp_json)
  {
   Print("Position modify request");
// fulfill default
   for(int i=0; i<resp_json["args"]["ticket"].Size(); i++)
     {
      double sl= resp_json["args"]["sl"][i].ToDbl();
      double tp= resp_json["args"]["tp"][i].ToDbl();
      // order allocation
      bool OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      bool status= OrderModify(OrderTicket(), 0, sl,tp,0, 0);
      if(status==true)
        {
         PrintFormat("position modify(ticket:%u) : Done",resp_json["args"]["ticket"][i].ToInt());
        }
      else
        {
         PrintFormat("position modify(ticket:%u) : Fail (%u)");
        }
     }
  }
  */
//+------------------------------------------------------------------+
void PositionClose(CJAVal &resp_json)
  {
   Print("Position close request");
// fulfill default
   int magic=MagicNumber;

   color OrderColor=clrWhite;
   double price=0;
   type X;
// fulfill from response
   for(int i=0; i<resp_json["args"]["ticket"].Size(); i++)
     {
      X=StringToEnum(resp_json["args"]["type"].ToStr(),D);
      if(X == S)
        {
         OrderColor = clrRed;
         price= Ask;
        }
      else
         if(X == B)
           {
            OrderColor = clrGreen;
            price= Bid;
           }
      bool status = OrderClose(OrderTicket(),OrderLots(),price,100,OrderColor);
      if(status==true)
        {
         PrintFormat("position close(ticket:%u) : Done",resp_json["args"]["ticket"][i].ToInt());
        }
      else
        {
         PrintFormat("position close(ticket:%u) : Done (%u)");
        }
     }
  }
//+------------------------------------------------------------------+
void close(int Magic)
  {
   for(int i = OrdersTotal() - 1 ; i>=0 ; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderMagicNumber() == Magic)
           {
            bool yccb = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 5, clrGreen) ;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//helpers
//+------------------------------------------------------------------+
int PositionsTotal()
  {
   int c=0;
   for(int i = OrdersTotal() - 1 ; i>=0 ; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderType()==OP_BUY || OrderType()==OP_SELL)
            c++;
        }
     }
   return(c);
  }
//+------------------------------------------------------------------+
int PositionGetTicket(int a)
  {
   int c=0;
   int d=0;
   for(int i = OrdersTotal() - 1 ; i>=0 ; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && (OrderType()==OP_BUY || OrderType()==OP_SELL))
        {
         d++;
         if(d==a)
            c=OrderTicket();
        }
     }
   return (c);
  }
//+------------------------------------------------------------------+
