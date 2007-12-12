//
//  YLSite.m
//  MacBlueTelnet
//
//  Created by Lan Yung-Luen on 11/20/07.
//  Copyright 2007 yllan.org. All rights reserved.
//

#import "YLSite.h"

@implementation YLSite

- (id) init {
    if ([super init]) {
        [self setName: @"Site Name"];
        [self setAddress: @"(your.site.org)"];
        [self setEncoding: YLBig5Encoding];
    }
    return self;
}

+ (YLSite *) siteWithDictionary: (NSDictionary *) d {
    YLSite *s = [[[YLSite alloc] init] autorelease];
    [s setName: [d valueForKey: @"name"]];
    [s setAddress: [d valueForKey: @"address"]];
    [s setEncoding: (YLEncoding)[[d valueForKey: @"encoding"] unsignedShortValue]];
    return s;
}

- (NSDictionary *) dictionaryOfSite {
    return [NSDictionary dictionaryWithObjectsAndKeys: [self name], @"name", [self address], @"address",
            [NSNumber numberWithUnsignedShort: [self encoding]], @"encoding", nil];
}

- (NSString *)name {
    return [[_name retain] autorelease];
}

- (void)setName:(NSString *)value {
    if (_name != value) {
        [_name release];
        _name = [value copy];
    }
}

- (NSString *)address {
    return [[_address retain] autorelease];
}

- (void)setAddress:(NSString *)value {
    if (_address != value) {
        [_address release];
        _address = [value copy];
    }
}

- (YLEncoding)encoding {
    return _encoding;
}

- (void)setEncoding:(YLEncoding)encoding {
    _encoding = encoding;
}

- (NSString *) description {
    return [NSString stringWithFormat: @"%@:%@", [self name], [self address]];
}

@end
