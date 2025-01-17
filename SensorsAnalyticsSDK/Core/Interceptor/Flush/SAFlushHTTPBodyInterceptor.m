//
// SAFlushHTTPBodyInterceptor.m
// SensorsAnalyticsSDK
//
// Created by 张敏超🍎 on 2022/4/11.
// Copyright © 2015-2022 Sensors Data Co., Ltd. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SAFlushHTTPBodyInterceptor.h"
#import "NSString+SAHashCode.h"
#import "SAGzipUtility.h"
#import "SAEventRecord.h"
#import "SAConstants+Private.h"

@implementation SAFlushHTTPBodyInterceptor

- (void)processWithInput:(SAFlowData *)input completion:(SAFlowDataCompletion)completion {
    NSParameterAssert(input.configOptions);
    NSParameterAssert(input.records.count > 0);

    NSData *httpBody = [self buildBodyWithInput:input];
    if (!httpBody) {
        input.state = SAFlowStateError;
        input.message = @"Event message base64Encoded or Gzip compression failed, End the track flow";
        return completion(input);
    }

    input.HTTPBody = httpBody;
    completion(input);
}

- (NSData *)buildBodyWithInput:(SAFlowData *)input {
    NSDictionary *bodyDic = [self buildBodyWithFlowData:input];
    if (!bodyDic) {
        return nil;
    }
    NSNumber *gzip = bodyDic[kSAFlushBodyKeyGzip];
    NSString *data = bodyDic[kSAFlushBodyKeyData];
    int hashCode = [data sensorsdata_hashCode];

    data = [data stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *bodyString = [NSString stringWithFormat:@"crc=%d&gzip=%d&data_list=%@", hashCode, [gzip intValue], data];
    if (input.isInstantEvent) {
        bodyString = [bodyString stringByAppendingString:@"&instant_event=true"];
    }
    if (input.isAdsEvent) {
        bodyString = [bodyString stringByAppendingString:@"&sink_name=mirror"];
    }
    return [bodyString dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSDictionary *)buildBodyWithFlowData:(SAFlowData *)flowData {
    NSString *jsonString = flowData.json;
    // 使用gzip进行压缩
    NSData *zippedData = [SAGzipUtility gzipData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
    if (!zippedData) {
        return nil;
    }
    // base64
    NSString *base64String = [zippedData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn];
    if (!base64String || ![base64String isKindOfClass:NSString.class]) {
        return nil;
    }
    NSDictionary *bodyDic = @{kSAFlushBodyKeyGzip: @(kSAFlushGzipCodePlainText), kSAFlushBodyKeyData: base64String};
    return bodyDic;
}

@end
