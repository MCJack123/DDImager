//
//  main.c
//  setuid
//
//  Created by Homework User on 12/7/17.
//  Copyright © 2017 JackMacWindows. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#import <Foundation/Foundation.h>

#define die(e) do {fprintf(stderr, "%s\n", e); exit(EXIT_FAILURE);} while (0);

static void alertTerm(int signo) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TerminateProcess" object:nil];
}

int main(int argc, char ** argv) {
    if (argc < 2) {
        printf("not enough arguments\n");
        return -1;
    }
    if (0 != setuid(0)) {
        printf("setuid failed\n");
        return -3;
    }
    int i;
    NSMutableArray<NSString *> *argvz = [[NSMutableArray<NSString *> alloc] init];
    for (i = 2; i < argc; i++) {
        argvz[i-2] = [[NSString alloc] initWithCString:argv[i] encoding:NSUTF8StringEncoding];
    }
    
    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath:[[NSString alloc] initWithCString:argv[1] encoding:NSUTF8StringEncoding]];
    [task setArguments:argvz];
    NSPipe * outt = [NSPipe pipe];
    [task setStandardOutput:outt];
    NSFileHandle *stdoutHandle = [outt fileHandleForReading];
    [stdoutHandle waitForDataInBackgroundAndNotify];
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification object:stdoutHandle queue:nil usingBlock:^(NSNotification *note) {
        NSData *dataRead = [stdoutHandle availableData];
        NSString *stringRead = [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];
        fprintf(stdout, "%s", [stringRead cStringUsingEncoding:NSASCIIStringEncoding]);
        fflush(stdout);
        
        [stdoutHandle waitForDataInBackgroundAndNotify];
    }];
    [task launch];
    signal(SIGTERM, alertTerm);
    signal(SIGINT, alertTerm);
    id term = [[NSNotificationCenter defaultCenter] addObserverForName:@"TerminateProcess" object:nil queue:nil usingBlock:^(NSNotification *note) {
        [task terminate];
    }];
    [task waitUntilExit];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    [[NSNotificationCenter defaultCenter] removeObserver:term];
    
    //printf("execv returned?\n");
    return 0;
}
