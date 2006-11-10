//
//  YLTelnet.m
//  MacBlueTelnet
//
//  Created by Yung-Luen Lan on 2006/9/10.
//  Copyright 2006 yllan. All rights reserved.
//

#import "YLTelnet.h"
#import "YLTerminal.h"
#import <sys/types.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>


#ifdef __DUMPPACKET__
char *_commandName[] = { "SE", "NOP", "DM", "BRK", "IP", "AO", "AYT", "EC", "EL", "GA", "SB", "WILL", "WONT", "DO", "DONT", "IAC" };

void dump_packet(unsigned char *s, int length) {
	int i;
	char tmp[1024 * 512]; tmp[0] = '\0';
	for (i = 0; i < length; i++) {
		if (s[i] >= SE) sprintf(tmp, "%s(%s)", tmp, _commandName[s[i] - SE]);
		else if (s[i] == 13) sprintf(tmp, "%s(CR)", tmp);
		else if (s[i] == 10) sprintf(tmp, "%s(LF)", tmp);
		else if (s[i] >= 127 || s[i] < 32) sprintf(tmp, "%s[%#x]", tmp, s[i]);
		else sprintf(tmp, "%s%c", tmp, s[i]);
	}
	NSLog(@"%s", tmp);
}
#endif

@implementation YLTelnet

- (BOOL) connectToAddress: (NSString *) addr port: (unsigned int) port{
	
	return YES;
}

- (BOOL) connectToIP: (NSString *) ip port: (unsigned int) port {
	int sockfd = socket(AF_INET, SOCK_STREAM, 0);
	struct sockaddr_in serverAddress;
	if (sockfd < 0) {
		// set error code
		return NO;
	}
	
	bzero( &serverAddress, sizeof(serverAddress) );
	serverAddress.sin_family = AF_INET;
	serverAddress.sin_port = htons(port);
	
	inet_pton( AF_INET, [ip UTF8String], &serverAddress.sin_addr );
	
	if ( connect( sockfd, (struct sockaddr *)&serverAddress, sizeof(serverAddress)) < 0 ) {
		// set error code
		return NO;
	}

	_server = [[NSFileHandle alloc] initWithFileDescriptor: sockfd closeOnDealloc: YES];

    [[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(receiveMessage:)
												 name: NSFileHandleReadCompletionNotification
											   object: _server];
	[_server readInBackgroundAndNotify];
	return YES;
}

/* Send telnet command */
- (void) sendCommand: (unsigned char) _command option: (unsigned char) _opt {
	unsigned char b[3];
	b[0] = IAC;
	b[1] = _command;
	b[2] = _opt;
	[_server writeData: [NSData dataWithBytes: b length: 3]];
}

- (void) sideEffectForOption: (const struct Opt *) o enabled: (BOOL) enabled {
	if (o->option == TELOPT_ECHO && o->send == DO)
		_echoing = !enabled;
	else if (o->option == TELOPT_SGA && o->send == DO) 
		_editing = !enabled;
	// TODO: notify "ldisc"
	
	if (!_activated) {
		if (_optStates[o_echo.index] == INACTIVE) {
			_optStates[o_echo.index] == REQUESTED;
			[self sendCommand: o_echo.send option: o_echo.option];
		}
		if (_optStates[o_we_sga.index] == INACTIVE) {
			_optStates[o_we_sga.index] == REQUESTED;
			[self sendCommand: o_we_sga.send option: o_we_sga.option];
		}
		if (_optStates[o_they_sga.index] == INACTIVE) {
			_optStates[o_they_sga.index] = REQUESTED;
			[self sendCommand: o_they_sga.send option: o_they_sga.option];
		}
		_activated = YES;
	}
}

- (void) deactivateOption: (const struct Opt *) o  {
	if (_optStates[o->index] == REQUESTED || _optStates[o->index] == ACTIVE)
		[self sendCommand: o->nsend option: o->option];
	_optStates[o->index] = REALLY_INACTIVE;
}

- (void) activateOption: (const struct Opt *) o {
	if (o->send == WILL && o->option == TELOPT_NAWS)
		// TODO: change telnet size
		;
	if (o->send == WILL && 
		(o->option == TELOPT_NEW_ENVIRON ||
		 o->option == TELOPT_OLD_ENVIRON)) {
		[self deactivateOption: (o->option == TELOPT_NEW_ENVIRON) ? &o_oenv : &o_nenv];
	}
	[self sideEffectForOption: o enabled: YES];
}

- (void) refusedOption: (const struct Opt *) o {
	if (o->send == WILL && o->option == TELOPT_NEW_ENVIRON && _optStates[o_oenv.index] == INACTIVE) {
		[self sendCommand: WILL option: TELOPT_OLD_ENVIRON];
		_optStates[o_oenv.index] = REQUESTED;
	}
	[self sideEffectForOption: o enabled: NO];
}

- (void) processCommand: (int) _command option: (int) _opt {
	const struct Opt *const *o;
	for (o = opts; *o; o++) {
		if ((*o)->option == _opt && (*o)->ack == _command) {
			switch (_optStates[(*o)->index]) {
				case REQUESTED:
					_optStates[(*o)->index] = ACTIVE;
					[self activateOption: *o];
					break;
				case ACTIVE:
					break;
				case INACTIVE:
					_optStates[(*o)->index] = ACTIVE;
					[self sendCommand: (*o)->send option: _opt];
					[self activateOption: *o];
					break;
				case REALLY_INACTIVE:
					[self sendCommand: (*o)->nsend option: _opt];
					break;
			}
			return;
		} else if ((*o)->option == _opt && (*o)->nak == _command) {
			switch (_optStates[(*o)->index]) {
				case REQUESTED:
					_optStates[(*o)->index] = INACTIVE;
					[self refusedOption: *o];
					break;
				case ACTIVE:
					_optStates[(*o)->index] = INACTIVE;
					[self sendCommand:(*o)->nsend option: _opt];
					[self sideEffectForOption: *o enabled: NO];
					break;
				case INACTIVE:
				case REALLY_INACTIVE:
					break;
			}
			return;
		}
	}
	
	/*
     * If we reach here, the option was one we weren't prepared to
     * cope with. If the request was positive (WILL or DO), we send
     * a negative ack to indicate refusal. If the request was
     * negative (WONT / DONT), we must do nothing.
     */	
	if (_command == WILL || _command == DO)
		[self sendCommand: (_command == WILL ? DONT : WONT) option: _opt];
		return;
}

- (void) processSubnegotiation {
	unsigned char b[2048], *p, *q;
	int var, value, n;
	char *e;
	const char *buf = [_sbBuffer bytes];
	
	switch (_sbOption) {
		case TELOPT_TSPEED:
			if ([_sbBuffer length] == 1 && buf[0] == TELQUAL_SEND) {
				char *logbuf;
				b[0] = IAC;
				b[1] = SB;
				b[2] = TELOPT_TSPEED;
				b[3] = TELQUAL_IS;
				// copy from config
				b[n] = IAC;
				b[n + 1] = SE;
				[self sendBytes: b length: n + 2];
				
			}
	}
	
}


- (void) receiveMessage: (NSNotification *) notify {
	NSData *messageData = [[notify userInfo] objectForKey: NSFileHandleNotificationDataItem];
	unsigned char *stream = (unsigned char *) [messageData bytes];
	
	/* parse the telnet command. */
	int L = [messageData length];
#ifdef __DUMPPACKET__
	dump_packet(stream, L);
#endif
	
	while (L--) {
		unsigned char c = *stream++;
		switch (_state) {
			case TOP_LEVEL:
			case SEENCR:
				if (c == NUL && _state == SEENCR)
					_state = TOP_LEVEL;
				else if (c == IAC)
					_state = SEENIAC;
				else {
					if (!_synch)
						//cwrite(c);
						printf("");
					else if (c == DM)
						_synch = NO;
					
					if (c == CR && _optStates[o_they_bin.index] != ACTIVE) 
						_state = SEENCR;
					else
						_state = TOP_LEVEL;
				}
				break;
			case SEENIAC:
				if (c == DO)
					_state = SEENDO;
				else if (c == DONT)
					_state = SEENDONT;
				else if (c == WILL)
					_state = SEENWILL;
				else if (c == WONT)
					_state = SEENWONT;
				else if (c == SB)
					_state = SEENSB;
				else if (c == DM) {
					_synch = NO;
					_state = TOP_LEVEL;
				} else {
					/* ignore everything else; print it if it's IAC */
					if (c == IAC) {
						//cwrite(c);
					}
					_state = TOP_LEVEL;
				}
				break;
			case SEENWILL:
				[self processCommand: WILL option: c];
				_state = TOP_LEVEL;
				break;
			case SEENWONT:
				[self processCommand: WONT option: c];
				_state = TOP_LEVEL;
				break;
			case SEENDO:
				[self processCommand: DO option: c];
				_state = TOP_LEVEL;
				break;
			case SEENDONT:
				[self processCommand: DONT option: c];
				_state = TOP_LEVEL;
				break;
			case SEENSB:
				_sbOption = c;
				_sbBuffer = [NSMutableData data];
				_state = SUBNEGOT;
				break;
			case SUBNEGOT:
				if (c == IAC)
					_state = SUBNEG_IAC;
				else 
					[_sbBuffer appendBytes: &c length: 1];
				break;
			case SUBNEG_IAC:
				if (c != SE) {
					[_sbBuffer appendBytes: &c length: 1];
					_state = SUBNEGOT;
				} else {
					[self processSubnegotiation];
					_state = TOP_LEVEL;
				}
				break;
		}
	}
	
	[_server readInBackgroundAndNotify];
	
}

- (void) sendBytes: (unsigned char *) _msg length: (unsigned int) length {
	
}

- (void) sendMessage: (NSData *) _msg {
	
}


- (NSString *) lastError {
	return @"I don't know what error.";
}

- (void) setTerminal: (YLTerminal *) _term {
	if (_term != _terminal) {
		[_terminal release];
		_terminal = [_term retain];
	}
}

@end
