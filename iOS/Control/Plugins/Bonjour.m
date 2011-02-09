//
//  Bonjour.m
//  PhoneGap
//
//  Created by Brant Vasilieff on 3/1/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "Bonjour.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#include <ifaddrs.h>

@implementation Bonjour
@synthesize isConnected, browser, services, connectedService, midiBrowser;

- (PhoneGapCommand*) initWithWebView:(UIWebView*)theWebView {	
    self = [super init];
    if (self) {
		__identifier = nil;
        [self setWebView:theWebView];
		services = [NSMutableArray new];
		count = 0;
	}
    return self;
}

- (void)start:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	netService = [[NSNetService alloc] initWithDomain:@"local." type:@"_osc._udp." 
												 name:@"Control:7865" port:7865];
    netService.delegate = self;
    [netService publish];
	
	self.browser = [[NSNetServiceBrowser new] autorelease];
    self.browser.delegate = self;
	
	self.midiBrowser = [[NSNetServiceBrowser new] autorelease];
    self.midiBrowser.delegate = self;
	
    self.isConnected = NO;
    [self.browser searchForServicesOfType:@"_osc._udp." inDomain:@""];
	[self.midiBrowser searchForServicesOfType:@"_apple-midi._udp." inDomain:@""];
	
	
	myIP = [self getIPAddress];
	[myIP retain];
	NSLog(myIP);
}

- (void)stop:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options { }

#pragma mark Net Service Browser Delegate Methods
-(void)netServiceBrowser:(NSNetServiceBrowser *)aBrowser didFindService:(NSNetService *)aService moreComing:(BOOL)more {
	[services addObject:aService];

	//NSLog([aService description]);
	NSNetService *remoteService = aService;
    remoteService.delegate = self;
    [remoteService resolveWithTimeout:0];
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aBrowser didRemoveService:(NSNetService *)aService moreComing:(BOOL)more {
    [services removeObject:aService];
    if ( aService == self.connectedService ) self.isConnected = NO;}

-(void)netServiceDidResolveAddress:(NSNetService *)service {
    self.isConnected = YES;
    self.connectedService = service;
	
	NSArray *addresses = service.addresses;
	//for(NSData *d in addresses) {
    @try {
        NSData * d = [addresses objectAtIndex:0];
        struct sockaddr_in *socketAddress  = (struct sockaddr_in *) [d bytes];
        
        int port;
        //NSLog(@"resolving!");
        for(NSData *d in [service addresses]) {
            struct sockaddr_in *socketAddress  = (struct sockaddr_in *) [d bytes];
            NSString *name = [service name];
            socketAddress = (struct sockaddr_in *)[d bytes];
            char * ipaddress = inet_ntoa(socketAddress->sin_addr);
			//NSLog(@"ipaddress = %s, myip = %s", ipaddress, [myIP UTF8String]);
            if(strcmp(ipaddress, "0.0.0.0") == 0 || strcmp(ipaddress, [myIP UTF8String]) == 0) { 
                continue;
            }
            port = ntohs(socketAddress->sin_port); // ntohs converts from network byte order to host byte order 
            BOOL isMIDI = ([[service type] isEqualToString:@"_apple-midi._udp."]);
            NSString *ipString = [NSString stringWithFormat: @"destinationManager.addDestination(\"%s\", %d, %d, %d);", inet_ntoa(socketAddress->sin_addr), port, !isMIDI, isMIDI];
            //NSLog([service type]); 
            //NSLog(ipString);
            [webView stringByEvaluatingJavaScriptFromString:ipString];
            
            //NSLog(@"Server found is %@ %d",ipString,port);
        }
    } @catch(NSException *e) { NSLog(@"error resolving bonjour address"); }
}

-(void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict {
    NSLog(@"Could not resolve: %@", errorDict);
}

- (NSString *)getIPAddress {
  NSString *address = @"error";
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  int success = 0;

  // retrieve the current interfaces - returns 0 on success
  success = getifaddrs(&interfaces);
  if (success == 0) {
    // Loop through linked list of interfaces
    temp_addr = interfaces;
    while(temp_addr != NULL) {
      if(temp_addr->ifa_addr->sa_family == AF_INET) {
        // Check if interface is en0 which is the wifi connection on the iPhone
        if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
          // Get NSString from C String
          address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
        }
      }
      temp_addr = temp_addr->ifa_next;
    }
  }

  // Free memory
  freeifaddrs(interfaces);

  return address;
}

- (void)dealloc {
	[myIP release];
	[services release];
	[browser release];
    [midiBrowser release];
    [__identifier release];
    [super dealloc];
}

@end