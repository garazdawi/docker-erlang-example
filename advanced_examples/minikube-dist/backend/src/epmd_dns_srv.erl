%%
%% Copyright Ericsson AB 2002-2014. All Rights Reserved.
%%
%% File:    epmd_dns_srv.erl
%% Author:  Lukas Larsson
%% Created: 2019-12-17
%%

-module(epmd_dns_srv).

-export([start_link/0, register_node/2, register_node/3, address_please/3,
         port_please/2, port_please/3]).

-include_lib("kernel/include/logger.hrl").
-include_lib("kernel/include/inet.hrl").
%% API.

start_link() ->
    erl_epmd:start_link().

register_node(Name, Port) ->
    register_node(Name, Port, inet_tcp).
register_node(Name, Port, Driver) ->
    %% Try to register with local epmd, if it does not exist
    %% we just return a random creation.
    case erl_epmd:register_node(Name, Port, Driver) of
        {error,econnrefused} ->
            {ok, create_creation()};
        EpmdRes ->
            EpmdRes
    end.

create_creation() ->
    Creation =
        try binary:decode_unsigned(crypto:strong_rand_bytes(4))
        catch _:_ ->
                rand:uniform((1 bsl 32)-1)
        end,

    %% We can only use large creations in OTP-23 and later
    case list_to_integer(erlang:system_info(otp_release)) of
        Rel when Rel > 22 ->
            Creation;
        _ ->
            Creation rem 3
    end.

address_please(Name, Host, Family) ->
    case inet:gethostbyname(Host, Family) of
        {ok,#hostent{ h_name = FQDN, h_addr_list = [Addr|_] }} ->
            case inet_res:lookup(FQDN,in,srv) of
                [{_Prio,_Weight,Prt,FQDN}] ->
                    {ok,Addr,Prt,5};
                _ ->
                    %% Returning this triggers a port_please call
                    ?LOG_INFO("DNS SRV lookup of \"~s@~s\" failed, using trying epmd",
                              [Name,Host]),
                    {ok,Addr}
            end
    end.

%% We just forward this to epmd as the SRV lookup failed
port_please(Node,Host) ->
    erl_epmd:port_please(Node,Host).
port_please(Node,Host,Timeout) ->
    erl_epmd:port_please(Node,Host,Timeout).
