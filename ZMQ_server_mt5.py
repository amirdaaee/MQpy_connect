import zmq
import time
import json
from abc import abstractmethod
import datetime
import traceback

# ------------------------------------------------------------------------------------------
# -------------------------------- Global Constants
# MT5 enums
mt5_enums = dict()
mt5_enums['position_open'] = {
    'action': ('TRADE_ACTION_DEAL', 'TRADE_ACTION_PENDING'),
    'type_order': (
        'ORDER_TYPE_BUY', 'ORDER_TYPE_SELL',
        'ORDER_TYPE_BUY_LIMIT', 'ORDER_TYPE_SELL_LIMIT',
        'ORDER_TYPE_BUY_STOP', 'ORDER_TYPE_SELL_STOP',
        'ORDER_TYPE_BUY_STOP_LIMIT', 'ORDER_TYPE_SELL_STOP_LIMIT'
    ),
    'type_filling': ('ORDER_FILLING_FOK', 'ORDER_FILLING_IOC'),
    'type_time': ('ORDER_TIME_GTC', 'ORDER_TIME_DAY', 'ORDER_TIME_SPECIFIED')
}


# ------------------------------------------------------------------------------------------
class Validator:
    # ------------------------------------------------------------
    # ------------------------------ pre definition
    func_argtype = {
        'position_open': {
            'action': mt5_enums['position_open']['action'],
            'volume': (float, int,),
            'price': (float, int, None),
            'stoplimit': (float, int, None),
            'deviation': (float, int, None),
            'sl': (float, int, None),
            'tp': (float, int, None),
            'type_order': mt5_enums['position_open']['type_order'],
            'type_filling': (*mt5_enums['position_open']['type_filling'], None),
            'type_time': (*mt5_enums['position_open']['type_time'], None),
            'expiration': (datetime.datetime, None)
        },
        'position_modify': {
            'ticket': (list,),
            'sl': (list, None),
            'tp': (list, None)
        },
        'position_modify_all': {
            'position_type': ('POSITION_TYPE_BUY', 'POSITION_TYPE_SELL', None),
            'sl': (float, None),
            'tp': (float, None)
        },
        'position_close': {
            'ticket': (list,),
            'volume': (list, None)
        },
        'position_close_all': {
            'position_type': ('POSITION_TYPE_BUY', 'POSITION_TYPE_SELL', None),
            'volume': (float, None)
        },
    }

    # .................................
    def __init__(self):
        pass

    # ------------------------------------------------------------
    # ------------------------------ validator helpers
    @classmethod
    def argtype_validation(cls, func, **kwargs):
        valid = cls.func_argtype[func]
        for k in valid.keys():
            val = kwargs[k]
            ref = valid[k]
            if val in ref or type(val) in ref:
                continue
            raise Exception('[E] in function {} call, arg {} should be in {} ({})'.format(func, k, ref, val))

    # .................................
    @staticmethod
    def pattern_validation(condition, check, check_names):
        """
        Parameters
        ----------
        condition : list[str]
        check   : list[bool]
        check_names : list[str]

        """

        if not all(check):
            e = '[E] pattern inconsistent\n'
            e += 'condition: '
            for c, i in enumerate(condition):
                e += str(i)
                if c < len(condition) - 1:
                    e += '->'
            e += '\n'
            e += 'check args: {}\n'.format(check_names)
            e += 'accepted: {}'.format(check)
            raise Exception(e)


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
                      action=mt5_enums['position_open']['action'][0],
                      volume=0.01,
                      price=None,
                      stoplimit=None,
                      deviation=None,
                      sl=None,
                      tp=None,
                      type_order=mt5_enums['position_open']['type_order'][0],
                      type_filling=None,
                      type_time=None,
                      expiration=None):
        """
        request structure for new order request
        +required args:
            action
            volume
            type_order
        +optional args:
            sl
            tp
            deviation
        pattens:
            ?action == TRADE_ACTION_DEAL
            +required args:
                type_order[ORDER_TYPE_BUY,ORDER_TYPE_SELL],type_filling
            ?action == TRADE_ACTION_PENDING
                +required args:
                    type_order[ORDER_TYPE_BUY_LIMIT,ORDER_TYPE_SELL_LIMIT,
                        ORDER_TYPE_BUY_STOP,ORDER_TYPE_SELL_STOP,
                        ORDER_TYPE_BUY_STOP_LIMIT,ORDER_TYPE_SELL_STOP_LIMIT],price,type_time
                ?type_order == ORDER_TYPE_BUY_STOP_LIMIT or ORDER_TYPE_SELL_STOP_LIMIT
                    +required args:
                        stoplimit
                ?type_time == ORDER_TIME_SPECIFIED
                    +required args:
                        expiration

        Parameters
        ----------
        action : str
            one of _RespValidator.open_order_enums['action'] values
        volume : float
        price,stoplimit,deviation,sl,tp : float, optional
        type_order : str
            one of _RespValidator.open_order_enums['type_order'] values
        type_filling : str or None
            one of _RespValidator.open_order_enums['type_filling'] values
        type_time : str or None
            one of _RespValidator.open_order_enums['type_time'] values
        expiration : datetime.datetime or None

        Returns
        -------
        object

        """

        type(self)
        Validator.argtype_validation('position_open', **locals())
        resp = dict()
        resp['command'] = 'position_open'
        resp['args'] = dict()
        # non optional
        resp['args']['action'] = action
        resp['args']['volume'] = volume
        resp['args']['type'] = type_order
        # common optionals
        resp['args']['deviation'] = deviation
        resp['args']['sl'] = sl
        resp['args']['tp'] = tp
        # other
        for i in ['price', 'stoplimit', 'type_filling', 'type_time', 'expiration']:
            resp['args'][i] = None
        # pattern validation
        if action == "TRADE_ACTION_DEAL":
            cond = [action]
            check = [type_order in ['ORDER_TYPE_BUY', 'ORDER_TYPE_SELL'],
                     type_filling is not None]
            Validator.pattern_validation(cond, check, ['type_order', 'type_filling'])
            resp['args']['type_filling'] = type_filling

        elif action == "TRADE_ACTION_PENDING":
            cond = [action]
            check = [type_order in ['ORDER_TYPE_BUY_LIMIT', 'ORDER_TYPE_SELL_LIMIT',
                                    'ORDER_TYPE_BUY_STOP', 'ORDER_TYPE_SELL_STOP',
                                    'ORDER_TYPE_BUY_STOP_LIMIT', 'ORDER_TYPE_SELL_STOP_LIMIT'],
                     price is not None,
                     type_time is not None, ]
            Validator.pattern_validation(cond, check, ['type_order', 'price', 'type_time'])
            if type_order in ['ORDER_TYPE_BUY_STOP_LIMIT', 'ORDER_TYPE_SELL_STOP_LIMIT']:
                cond = [action, type_order]
                check = [stoplimit is not None]
                Validator.pattern_validation(cond, check, ['stoplimit'])
            if type_time == 'ORDER_TIME_SPECIFIED':
                cond = [action, type_time]
                check = [expiration is not None]
                Validator.pattern_validation(cond, check, ['expiration'])
            resp['args']['price'] = price
            resp['args']['stoplimit'] = stoplimit
            resp['args']['type_time'] = type_time
            resp['args']['expiration'] = expiration
            if resp['args']['expiration'] is not None:
                resp['args']['expiration'] = resp['args']['expiration'].strftime("%Y.%m.%d %H:%M")

        return resp

    # .................................
    def position_modify(self,
                        ticket,
                        sl=None,
                        tp=None):
        """
        modify positions based on ticket

        Parameters
        ----------
        ticket : list[int,str]
        sl,tp : list[float,None] or None

        Returns
        -------
        object

        """

        type(self)
        Validator.argtype_validation('position_modify', **locals())

        if sl is None:
            sl = [None] * len(ticket)
        if tp is None:
            tp = [None] * len(ticket)
        assert len(ticket) == len(sl) == len(tp), 'ticket, sl & tp should have same length'
        resp = dict()
        resp['command'] = 'position_modify'
        resp['args'] = dict()
        resp['args']['ticket'] = ticket
        resp['args']['sl'] = sl
        resp['args']['tp'] = tp
        return resp

    # .................................
    def position_modify_all(self,
                            position_type=None,
                            sl=None,
                            tp=None):
        """
        modify positions based on type

        Parameters
        ----------
        position_type : str or None
            'POSITION_TYPE_BUY' or 'POSITION_TYPE_SELL' or None
        sl,tp : float or None

        Returns
        -------
        object

        """

        Validator.argtype_validation('position_modify_all', **locals())
        if position_type is None:
            position_type = ('POSITION_TYPE_BUY', 'POSITION_TYPE_SELL')
        else:
            position_type = (position_type,)

        ticket = []
        if self.positions is None:
            raise Exception('no position data available')
        for position in self.positions:
            if position['type'] in position_type:
                ticket.append(position['ticket'])
        sl = [sl] * len(ticket)
        tp = [tp] * len(ticket)
        return self.position_modify(ticket, sl, tp)

    # .................................
    def position_close(self, ticket, volume=None):
        """
        close positions based on tickets

        Parameters
        ----------
        ticket : list[int,str]
        volume : list[float] or None
            None -> whole position

        Returns
        -------
        object

        """

        type(self)
        Validator.argtype_validation('position_close', **locals())

        if volume is None:
            volume = [None] * len(ticket)

        for c, i in enumerate(volume):
            if i is None:
                # noinspection PyTypeChecker
                volume[c] = -1
        assert len(ticket) == len(volume), 'ticket and volume should have same length'

        resp = dict()
        resp['command'] = 'position_close'
        resp['args'] = dict()
        resp['args']['ticket'] = ticket
        resp['args']['volume'] = volume
        return resp

    # .................................
    def position_close_all(self, position_type=None, volume=None):
        """
        close positions based on type

        Parameters
        ----------
        position_type : str or None
            'POSITION_TYPE_BUY' or 'POSITION_TYPE_SELL' or None
        volume : float or None

        Returns
        -------
        object

        """

        Validator.argtype_validation('position_close_all', **locals())
        if position_type is None:
            position_type = ('POSITION_TYPE_BUY', 'POSITION_TYPE_SELL')
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
