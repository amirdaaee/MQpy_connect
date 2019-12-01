import zmq
import time
import json
from abc import abstractmethod
import datetime
import traceback

class MTConnect:
    # ------------------------------------------------------------
    # ------------------------------ pre definition
    # template message
    _resp_empty = {'command': 'resume'}
    _resp_error = {'command': 'error'}
    # self variables
    positions = None
    orders = None
    # place holders
    response_functions = None

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

        self.set_defaults()
        self.ip = ip
        self.port = str(port)
        self.protocol = protocol
        self.network_path = "{}://{}:{}".format(protocol, ip, port)
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REP)
        self.socket.bind(self.network_path)
        self.verbuse = verbuse

    # .................................
    def set_defaults(self):
        self.response_functions = {
            "init": self.event_init_,
            "deinit": self.event_deinit_,
            "newtrade": self.event_newtrade_,
            "newbar": self.event_newbar_,
        }

    # ------------------------------------------------------------
    # ------------------------------ routines
    def listen(self):
        try:
            message = self._retrieve_()
            message = self._parse_(message)
            if self.verbuse:
                print(message)
            resp = self._act_(message)
            self._response_(resp)
            if self.verbuse:
                print(resp)
            return True
        except Exception as E:
            self._response_(self._resp_error)
            print('[Exception] following exception occurred:')
            traceback.print_tb(E.__traceback__)
            print(E)
            return False

    # .................................
    def _retrieve_(self):
        try:
            message = self.socket.recv()
        except zmq.error.ZMQError as E:
            if E.errno == 156384763:
                self._response_(self._resp_empty)
                message = self.socket.recv()
            else:
                raise Exception(E)
        return message

    @classmethod
    def _parse_(cls, message):
        message = str(message)[2:-1]
        message = json.loads(message)
        return message

    def _act_(self, message):
        fn = self.response_functions[message['event']]
        resp = fn(message['args'])
        return resp

    def _response_(self, message):
        if message is None:
            message = self._resp_empty
        message = json.dumps(message)
        time.sleep(1e-3)
        self.socket.send_string(message)

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
        volume : float
        sl,tp : float, optional
        Returns
        -------
        object

        """

        type(self)
        resp = dict()
        resp['command'] = 'position_open'
        resp['args'] = dict()
        # detailed argument
        resp['args']['type'] = type_order
        resp['args']['volume'] = volume
        resp['args']['sl'] = sl
        resp['args']['tp'] = tp
        return resp


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
    #
    # # .................................
    # def position_close(self, ticket, volume=None):
    #     """
    #     close positions based on tickets
    #
    #     Parameters
    #     ----------
    #     ticket : list[int,str]
    #     volume : list[float] or None
    #         None -> whole position
    #
    #     Returns
    #     -------
    #     object
    #
    #     """
    #
    #     type(self)
    #     Validator.argtype_validation('position_close', **locals())
    #
    #     if volume is None:
    #         volume = [None] * len(ticket)
    #
    #     for c, i in enumerate(volume):
    #         if i is None:
    #             # noinspection PyTypeChecker
    #             volume[c] = -1
    #     assert len(ticket) == len(volume), 'ticket and volume should have same length'
    #
    #     resp = dict()
    #     resp['command'] = 'position_close'
    #     resp['args'] = dict()
    #     resp['args']['ticket'] = ticket
    #     resp['args']['volume'] = volume
    #     return resp

    # .................................
    def position_close_all(self, position_type=None, volume=None):
        """
        close positions based on type

        Parameters
        ----------
        position_type : str or None
            'OP_BUY' or 'OP_SELL' or None
        volume : float or None

        Returns
        -------
        object

        """

        if position_type is None:
            position_type = ('OP_BUY', 'OP_SELL')
        else:
            position_type = (position_type,)

        ticket = []
        if self.positions is None:
            raise Exception('no position data available')
        for position in self.positions:
            if position['type'] in position_type:
                ticket.append(position['ticket'])
        volume = [volume] * len(ticket)
        return self.position_close(ticket, volume)

    # ------------------------------------------------------------
    # ------------------------------ request handlers
    def event_init_(self, message):
        print("client initialized : magic={}".format(message['magic']))
        position = message['position']
        order = message['order']

        if position == 'null':
            position = []
        if order == 'null':
            order = []

        self.positions = position
        self.orders = order
        return self.event_init(message)

    @abstractmethod
    def event_init(self, message):
        dict(message)
        return self._resp_empty

    # .................................
    def event_deinit_(self, message):
        print("client destroyed : magic={}".format(message['magic']))
        return self.event_deinit(message)

    @abstractmethod
    def event_deinit(self, message):
        dict(message)
        return self._resp_empty

    # .................................
    def event_newtrade_(self, message):
        position = message['position']
        order = message['order']

        if position == 'null':
            position = []
        if order == 'null':
            order = []

        self.positions = position
        self.orders = order
        return self.event_newtrade(message)

    @abstractmethod
    def event_newtrade(self, message):
        dict(message)
        return self._resp_empty

    # .................................
    def event_newbar_(self, message):
        return self.event_newbar(message)

    @abstractmethod
    def event_newbar(self, message):
        dict(message)
        return self._resp_empty
