//
// ModuleFormatter.m
//
// Copyright (C) 2019 Antony Chazapis SV9OAN
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#import "ModuleFormatter.h"

@implementation ModuleFormatter

- (NSString *)stringForObjectValue:(id)obj {
    if (obj != nil)
        return [NSString stringWithString:obj];
    return nil;
}

- (BOOL)getObjectValue:(out id _Nullable *)obj
             forString:(NSString *)string
      errorDescription:(out NSString * _Nullable *)error {
    *obj = [NSString stringWithString:string];
    return YES;
}

- (BOOL)isPartialStringValid:(NSString *)partialString
            newEditingString:(NSString * _Nullable *)newString
            errorDescription:(NSString * _Nullable *)error {
    if ([partialString length] == 0)
        return YES;
    if ([partialString length] > 1) {
        *newString = nil;
        return NO;
    }
    unichar c = [partialString characterAtIndex:0];
    if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z'))) {
        *newString = nil;
        return NO;
    }
    *newString = [partialString uppercaseString];
    return NO;
}

@end
