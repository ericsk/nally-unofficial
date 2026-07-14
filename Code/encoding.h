/*
 *  encoding.h
 *  Nally
 *
 *  Created by Yung-Luen Lan on 9/11/07.
 *  Copyright 2007 yllan.org. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>

extern unsigned short G2U[32768];
extern unsigned short B2U[32768];
extern unsigned short U2B[65536];
extern unsigned short U2G[65536];

extern void init_table();

static inline unichar lookupBig5(unsigned short index) { return B2U[index]; }
static inline unichar lookupGBK(unsigned short index) { return G2U[index]; }
