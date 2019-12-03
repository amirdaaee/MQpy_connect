import zmq
import time
import json
from abc import abstractmethod
from collections.abc import Iterable
import traceback
import pandas as pd


# todo: merge into ZMQ_server_mt5.py (this is better version)
class MTConnect:
    # ------------------------------------------------------------
    # ------------------------------ pre definition
    # template message
    __resp_empty__ = {'type': 'message', 'command': 'resume'}
    __resp_error__ = {'type': 'message', 'command': 'error'}
    # self variables
    empty_positions = pd.DataFrame(columns=['TICKET'])
    empty_orders = pd.DataFrame(columns=['TICKET'])
    positions = None
    orders = None
    dataset = None
    # place holders
    response_functions = None
    # remote enums
    order_type_translate = {
        'buy': 'OP_BUY',
        'sell': 'OP_SELL',
    }

    # .................................
    def __init__(self, ip='*', port='5556', protocol='tcp', verbuse=False):
        """
        Parameters
        ----------
        ip : str
        port : str
        protocol : {'tcp','udp'}
        verbuse : bool
        """

        self.__set_defaults__()
        self.ip = ip
        self.port = str(port)
        self.protocol = protocol
        self.network_path = "{}://{}:{}".format(protocol, ip, port)
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REP)
        self.socket.setsockopt(zmq.LINGER, 0)
        self.socket.setsockopt(zmq.IMMEDIATE, 1)
        self.socket.bind(self.network_path)
        self.verbuse = verbuse

    # .................................
    def __set_defaults__(self):
        self.response_functions = {
            "init": self.__event_init__,
            "deinit": self.__event_deinit__,
            "trade": self.__event_trade__,
            "newbar": self.__event_newbar__,
        }

    # ------------------------------------------------------------
    # ------------------------------ routines
    def run(self):
        while True:
            self.listen()

    # .................................
    def listen(self):
        try:
            message = self.__retrieve__()
            message = self.__parse__(message)
            if self.verbuse:
                print('receive:', message)
            resp = self.__act__(message)
            self.__response__(resp)
            if self.verbuse:
                print('response:', resp)
            return 0
        except Exception as E:
            self.__response__(self.__resp_error__)
            print('[Exception] following exception occurred:')
            traceback.print_tb(E.__traceback__)
            print(E)
            return E

    # .................................
    def __retrieve__(self):
        try:
            message = self.socket.recv()
        except zmq.error.ZMQError as E:
            if E.errno == 156384763:
                self.__response__(self.__resp_empty__)
                message = self.socket.recv()
            else:
                raise Exception(E)
        return message

    @staticmethod
    def __parse__(message):
        message = str(message)[2:-1]
        message = json.loads(message)
        return message

    def __act__(self, message):
        print('-' * 50, message['event'])
        fn = self.response_functions[message['event']]
        resp = fn(message['args'])
        return resp

    def __response__(self, message):
        if message is None:
            message = self.__resp_empty__
        message = json.dumps(message)
        time.sleep(1e-3)
        self.socket.send_string(message)

    def __update_db__(self, data):
        if 'position' in data.keys():
            position = data['position']
            if position == 'null':
                self.positions = self.empty_positions
            else:
                self.positions = pd.DataFrame.from_dict(position)
            if self.verbuse:
                print('positions:')
                print(self.positions)
        if 'order' in data.keys():
            order = data['order']
            if order == 'null':
                self.orders = self.empty_orders
            else:
                self.orders = pd.DataFrame.from_dict(order)
            if self.verbuse:
                print('orders:')
                print(self.orders)
        if 'dataset' in data.keys():
            dataset = data['dataset']
            dataset = pd.DataFrame.from_dict(dataset)
            if self.dataset is None:
                self.dataset = dataset
            else:
                self.dataset = self.dataset.append(dataset, ignore_index=True)
            self.dataset['DateTime'] = pd.to_datetime(self.dataset['DateTime'], format="%Y.%m.%d %H:%M")
            self.dataset = self.dataset.drop_duplicates(['DateTime'], keep='last')
            if self.verbuse:
                print('dataset:')
                print(self.dataset)

    # ------------------------------------------------------------
    # ------------------------------ action functions
    def position_open(self,
                      type_order,
                      volume=0.01,
                      sl=None,
                      tp=None):
        """
        Parameters
        ----------
        type_order : str
            'buy' or 'sell'
        volume : float
        sl,tp : float, optional

        Returns
        -------
        object
        """

        # todo:support for more type_order
        type(self)
        type_order = type_order.lower()
        type_order = self.order_type_translate[type_order]
        resp = dict()
        resp['type'] = 'action'
        resp['command'] = 'position_open'
        # detailed argument
        resp['args'] = dict()
        resp['args']['type'] = type_order
        resp['args']['volume'] = volume
        resp['args']['sl'] = sl
        resp['args']['tp'] = tp
        return resp

    # .................................
    def position_close(self, ticket, volume=None):
        """
        close positions based on tickets

        Parameters
        ----------
        ticket : Iterable[int,str] or int or str or None
            None -> all positions
        volume : Iterable[float,None] or None
            None -> whole position

        Returns
        -------
        object
        """

        type(self)
        if ticket is None:
            ticket = [x for x in self.positions['TICKET']]
            volume = None
        if volume is None:
            volume = [None] * len(ticket)
        volume = list(volume)

        for c, i in enumerate(volume):
            if i is None:
                volume[c] = -1
        assert len(ticket) == len(volume), 'ticket and volume should have same length'

        resp = dict()
        resp['command'] = 'position_close'
        resp['args'] = dict()
        resp['args']['ticket'] = ticket
        resp['args']['volume'] = volume
        return resp

    # ------------------------------------------------------------
    # ------------------------------ request handlers
    def __event_init__(self, message):
        print("client initialized : magic={} - symbol={}".format(message['magic'], message['symbol']))
        if message['version'].lower() != 'mt4':
            print('version mismatch :', message['version'])
            return self.__resp_error__
        self.__update_db__(message)
        return self.event_init(message)

    @abstractmethod
    def event_init(self, message):
        dict(message)
        return self.__resp_empty__

    # .................................
    def __event_deinit__(self, message):
        print("client destroyed : magic={}".format(message['magic']))
        return self.event_deinit(message)

    @abstractmethod
    def event_deinit(self, message):
        dict(message)
        return self.__resp_empty__

    # .................................
    def __event_trade__(self, message):
        print('change in orders or positions')
        self.__update_db__(message)
        return self.event_trade(message)

    @abstractmethod
    def event_trade(self, message):
        dict(message)
        return self.__resp_empty__

    # .................................
    def __event_newbar__(self, message):
        print('new bar')
        self.__update_db__(message)
        return self.event_newbar(message)

    @abstractmethod
    def event_newbar(self, message):
        dict(message)
        return self.__resp_empty__

# todo:following features
# .................................

# def position_modify(self,
#                     ticket,
#                     sl=None,
#                     tp=None):
#     """
#     modify positions based on ticket
#
#     Parameters
#     ----------
#     ticket : list[int,str]
#     sl,tp : list[float,None] or None
#
#     Returns
#     -------
#     object
#
#     """
#
#     type(self)
#
#     if sl is None:
#         sl = [None] * len(ticket)
#     if tp is None:
#         tp = [None] * len(ticket)
#     assert len(ticket) == len(sl) == len(tp), 'ticket, sl & tp should have same length'
#     resp = dict()
#     resp['command'] = 'position_modify'
#     resp['args'] = dict()
#     resp['args']['ticket'] = ticket
#     resp['args']['sl'] = sl
#     resp['args']['tp'] = tp
#     return resp
#
# # .................................
# def position_modify_all(self,
#                         position_type=None,
#                         sl=None,
#                         tp=None):
#     """
#     modify positions based on type
#
#     Parameters
#     ----------
#     position_type : str or None
#         'POSITION_TYPE_BUY' or 'POSITION_TYPE_SELL' or None
#     sl,tp : float or None
#
#     Returns
#     -------
#     object
#
#     """
#
#     Validator.argtype_validation('position_modify_all', **locals())
#     if position_type is None:
#         position_type = ('POSITION_TYPE_BUY', 'POSITION_TYPE_SELL')
#     else:
#         position_type = (position_type,)
#
#     ticket = []
#     if self.positions is None:
#         raise Exception('no position data available')
#     for position in self.positions:
#         if position['type'] in position_type:
#             ticket.append(position['ticket'])
#     sl = [sl] * len(ticket)
#     tp = [tp] * len(ticket)
#     return self.position_modify(ticket, sl, tp)
# # .................................
#     def position_close_type(self, position_type=None, volume=None):
#         """
#         close positions by type
#
#         Parameters
#         ----------
#         position_type : tuple or str or None
#             None = close all types
#         volume : float or None
#
#         Returns
#         -------
#         object
#         """
#
#         if position_type is None:
#             position_type = tuple(self.order_type_translate.values())
#         else:
#             position_type = (position_type,)
#
#         ticket = []
#         if self.positions is None:
#             raise Exception('no position data available')
#         for position in self.positions:
#             if position['type'] in position_type:
#                 ticket.append(position['ticket'])
#         volume = [volume] * len(ticket)
#         return self.position_close(ticket, volume)
