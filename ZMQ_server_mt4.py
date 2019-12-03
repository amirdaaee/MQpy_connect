import zmq
import time
import json
from abc import abstractmethod
from collections.abc import Iterable
import traceback
import pandas as pd


def isnonstriter(obj):
    return (not isinstance(obj, str)) and isinstance(obj, Iterable)


# todo: merge into ZMQ_server_mt5.py (this is better version)
class MTConnect:
    # ------------------------------------------------------------
    # ------------------------------ pre definition
    # self variables
    empty_positions = pd.DataFrame(columns=['Ticket'])
    empty_orders = pd.DataFrame(columns=['Ticket'])
    positions = empty_positions.copy()
    orders = empty_orders.copy()
    dataset = None
    # remote enums
    execution_type_translate = {
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
        self.verbuse = verbuse
        self.client_init = False
        self.network_path = "{}://{}:{}".format(protocol, ip, port)
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REP)
        self.socket.setsockopt(zmq.LINGER, 0)
        self.socket.setsockopt(zmq.IMMEDIATE, 1)
        self.socket.bind(self.network_path)
        print('server running at', self.network_path)

    # .................................
    def __set_defaults__(self):
        self.response_functions = {
            "init": self.__event_init__,
            "deinit": self.__event_deinit__,
            "trade": self.__event_trade__,
            "newbar": self.__event_newbar__,
            "tick": self.__event_tick__,
            "sync": self.__sync_db__,
        }
        self.__resp_empty__ = self.__response_template__('message', 'resume')
        self.__resp_error__ = self.__response_template__('message', 'error')

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
            if self.client_init or message['event'] == 'init' or message['event'] == 'sync':
                resp = self.__act__(message)
            else:
                print('client not initialized. skipping current event. syncing db...')
                resp = self.sync_req()
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

    def __parse__(self, message):
        type(self)
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
                self.positions = self.empty_positions.copy()
            else:
                self.positions = pd.DataFrame.from_dict(position)
            if self.verbuse:
                print('positions:')
                print(self.positions)
        if 'order' in data.keys():
            order = data['order']
            if order == 'null':
                self.orders = self.empty_orders.copy()
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

    @staticmethod
    def __response_template__(rtype, rcommand):
        """
        Parameters
        ----------
        rtype : str
        rcommand : str

        Returns
        -------
        Dict
        """
        return {'type': rtype, 'command': rcommand, 'args': {}}

    # ------------------------------------------------------------
    # ------------------------------ action functions
    def sync_req(self):
        resp = self.__response_template__('action', 'sync')
        self.client_init = True
        return resp

    # .................................
    def position_execute(self,
                         type_order,
                         volume=0.01,
                         sl=None,
                         tp=None,
                         comment=None):
        """
        Market Execution order

        Parameters
        ----------
        type_order : Iterable[str] or str
            'buy' or 'sell'
        volume : Iterable[float] or float
            if Iterable -> len == len(type_order)
        sl,tp : Iterable[float or None] or float or None
            None -> no sl or tp |
            if Iterable -> len == len(type_order)
        comment : Iterable[str or None] or str or None

        Returns
        -------
        object
        """

        type(self)
        if not isnonstriter(type_order):
            type_order = (type_order,)
        if not isinstance(volume, Iterable):
            volume = (volume,) * len(type_order)
        if not isinstance(sl, Iterable):
            sl = (sl,) * len(type_order)
        if not isinstance(tp, Iterable):
            tp = (tp,) * len(type_order)
        if not isnonstriter(comment):
            comment = (comment,) * len(type_order)

        assert len(type_order) == len(volume), 'len(volume) should be == len(type_order)'
        assert len(type_order) == len(sl), 'len(sl) should be == len(type_order)'
        assert len(type_order) == len(tp), 'len(tp) should be == len(type_order)'
        assert len(type_order) == len(comment), 'len(comment) should be == len(type_order)'

        orders = []
        for type_order_, volume_, sl_, tp_, comment_ in zip(type_order, volume, sl, tp, comment):
            type_order_ = self.execution_type_translate[type_order_.lower()]
            orders.append({'type': type_order_, 'volume': volume_, 'sl': sl_, 'tp': tp_, 'cm': comment_})

        resp = self.__response_template__('action', 'position_open')
        resp['args']['orderlist'] = orders
        return resp

    # .................................
    # todo:support for pending positions
    def position_pending(self):
        """pending order"""
        raise Exception('still developing')

    # .................................
    def position_modify(self,
                        ticket=None,
                        sl=None,
                        tp=None):
        """
        modify positions based on ticket

        Parameters
        ----------
        ticket : Iterable[int,str] or int or str or None
            None -> all positions
        sl,tp : Iterable[float or None] or float or None
            None -> no sl or tp |
            -1 -> dont change |
            if Iterable -> len == len(type_order)

        Returns
        -------
        object
        """

        type(self)
        if ticket is None:
            ticket = [x for x in self.positions['Ticket']]
        if not isnonstriter(ticket):
            ticket = (ticket,)
        if not isinstance(sl, Iterable):
            sl = (sl,) * len(ticket)
        if not isinstance(tp, Iterable):
            tp = (tp,) * len(ticket)

        assert len(ticket) == len(sl), 'len(sl) should be == len(type_order)'
        assert len(ticket) == len(tp), 'len(tp) should be == len(type_order)'

        modifies = []
        for ticket_, sl_, tp_ in zip(ticket, sl, tp):
            modifies.append({'ticket': ticket_, 'sl': sl_, 'tp': tp_})

        resp = self.__response_template__('action', 'position_modify')
        resp['args']['modifylist'] = modifies

        return resp

    # .................................
    def position_close(self, ticket=None):
        """
        close positions based on tickets

        Parameters
        ----------
        ticket : Iterable[int,str] or int or str or None
            None -> all positions

        Returns
        -------
        object
        """

        type(self)
        if ticket is None:
            ticket = [x for x in self.positions['Ticket']]
        elif not isnonstriter(ticket):
            ticket = (ticket,)
        resp = self.__response_template__('action', 'position_close')
        resp['args']['ticketlist'] = ticket
        return resp

    # ------------------------------------------------------------
    # ------------------------------ request handlers
    def __event_init__(self, message):
        print("client initialized : magic={} - symbol={}".format(message['magic'], message['symbol']))
        if message['version'].lower() != 'mt4':
            print('version mismatch :', message['version'])
            return self.__resp_error__
        self.__update_db__(message)
        self.client_init = True
        return self.event_init(message)

    @abstractmethod
    def event_init(self, message):
        dict(message)
        return self.__resp_empty__

    # .................................
    def __event_deinit__(self, message):
        print("client destroyed : magic={}".format(message['magic']))
        self.client_init = False
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

    # .................................
    def __event_tick__(self, message):
        print('tick')
        self.__update_db__(message)
        return self.event_tick(message)

    @abstractmethod
    def event_tick(self, message):
        dict(message)
        return self.__resp_empty__

    # .................................
    def __sync_db__(self, message):
        print('db sync')
        self.__update_db__(message)
        return self.__resp_empty__
