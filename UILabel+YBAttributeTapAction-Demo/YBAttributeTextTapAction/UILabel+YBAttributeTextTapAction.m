//
//  UILabel+YBAttributeTextTapAction.m
//
//  Created by LYB on 16/7/1.
//  Copyright © 2016年 LYB. All rights reserved.
//

#import "UILabel+YBAttributeTextTapAction.h"
#import <objc/runtime.h>
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>

@implementation YBAttributeModel

@end

@implementation UILabel (YBAttributeTextTapAction)

#pragma mark - AssociatedObjects

- (NSMutableArray *)attributeStrings
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setAttributeStrings:(NSMutableArray *)attributeStrings
{
    objc_setAssociatedObject(self, @selector(attributeStrings), attributeStrings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)effectDic
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setEffectDic:(NSMutableDictionary *)effectDic
{
    objc_setAssociatedObject(self, @selector(effectDic), effectDic, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isTapAction
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setIsTapAction:(BOOL)isTapAction
{
    objc_setAssociatedObject(self, @selector(isTapAction), @(isTapAction), OBJC_ASSOCIATION_ASSIGN);
}

- (void (^)(NSString *, NSRange, NSInteger))tapBlock
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTapBlock:(void (^)(NSString *, NSRange, NSInteger))tapBlock
{
    objc_setAssociatedObject(self, @selector(tapBlock), tapBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (id<YBAttributeTapActionDelegate>)delegate
{
    return objc_getAssociatedObject(self, _cmd);
}

- (BOOL)enabledTapEffect
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setEnabledTapEffect:(BOOL)enabledTapEffect
{
    objc_setAssociatedObject(self, @selector(enabledTapEffect), @(enabledTapEffect), OBJC_ASSOCIATION_ASSIGN);
    self.isTapEffect = enabledTapEffect;
}

- (BOOL)isTapEffect
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setIsTapEffect:(BOOL)isTapEffect
{
    objc_setAssociatedObject(self, @selector(isTapEffect), @(isTapEffect), OBJC_ASSOCIATION_ASSIGN);
}

- (void)setDelegate:(id<YBAttributeTapActionDelegate>)delegate
{
    objc_setAssociatedObject(self, @selector(delegate), delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - mainFunction
- (void)yb_addAttributeTapActionWithStrings:(NSArray <NSString *> *)strings tapClicked:(void (^) (NSString *string , NSRange range , NSInteger index))tapClick
{
    [self yb_getRangesWithStrings:strings];
    
    if (self.tapBlock != tapClick) {
        self.tapBlock = tapClick;
    }
}

- (void)yb_addAttributeTapActionWithStrings:(NSArray <NSString *> *)strings
                                   delegate:(id <YBAttributeTapActionDelegate> )delegate
{
    [self yb_getRangesWithStrings:strings];
    
    if (self.delegate != delegate) {
        self.delegate = delegate;
    }
}

#pragma mark - touchAction
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (!self.isTapAction) {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    
    CGPoint point = [touch locationInView:self];
    
    __weak typeof(self) weakSelf = self;
    
    [self yb_getTapFrameWithTouchPoint:point result:^(NSString *string, NSRange range, NSInteger index) {
        
        if (weakSelf.tapBlock) {
            weakSelf.tapBlock (string , range , index);
        }
        
        if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(yb_attributeTapReturnString:range:index:)]) {
            [weakSelf.delegate yb_attributeTapReturnString:string range:range index:index];
        }
        
        if (weakSelf.isTapEffect) {
            
            [weakSelf yb_saveEffectDicWithRange:range];
            
            [weakSelf yb_tapEffectWithStatus:YES];
        }
        
    }];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    
    if (self.isTapAction) {
        if ([self yb_getTapFrameWithTouchPoint:point result:nil]) {
            return self;
        }
    }
    return nil;
}

#pragma mark - getTapFrame
- (BOOL)yb_getTapFrameWithTouchPoint:(CGPoint)point result:(void (^) (NSString *string , NSRange range , NSInteger index))resultBlock
{
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.attributedText);
    
    CGMutablePathRef Path = CGPathCreateMutable();
    
    CGPathAddRect(Path, NULL, self.frame);
    
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), Path, NULL);
    
    CFArrayRef lines = CTFrameGetLines(frame);
    
    if (!lines) {
        return NO;
    }
    
    CFIndex count = CFArrayGetCount(lines);
    
    CGPoint origins[count];
    
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
    
    CGAffineTransform transform = [self yb_transformForCoreText];
    
    CGFloat verticalOffset = 0;
    
    for (CFIndex i = 0; i < count; i++) {
        CGPoint linePoint = origins[i];
        
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        
        CGRect flippedRect = [self yb_getLineBounds:line point:linePoint];
        
        CGRect rect = CGRectApplyAffineTransform(flippedRect, transform);
        
        rect = CGRectInset(rect, 0, 0);
        
        rect = CGRectOffset(rect, 0, verticalOffset);
        
        NSParagraphStyle *style = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:nil];
        
        CGFloat lineSpace = style.lineSpacing;
        
        CGFloat lineOutSpace = (self.bounds.size.height - lineSpace * (count - 1) -rect.size.height * count) / 2;
        
        rect.origin.y = lineOutSpace + rect.size.height * i + lineSpace * i;
        
        if (CGRectContainsPoint(rect, point)) {
            
            CGPoint relativePoint = CGPointMake(point.x - CGRectGetMinX(rect), point.y - CGRectGetMinY(rect));

            CFIndex index = CTLineGetStringIndexForPosition(line, relativePoint);
            
            CGFloat offset;
            
            CTLineGetOffsetForStringIndex(line, index, &offset);
            
            if (offset > relativePoint.x) {
                index = index - 1;
            }
            
            NSInteger link_count = self.attributeStrings.count;
            
            for (int j = 0; j < link_count; j++) {
                
                YBAttributeModel *model = self.attributeStrings[j];
                
                NSRange link_range = model.range;
                if (NSLocationInRange(index, link_range)) {
                    if (resultBlock) {
                        resultBlock (model.str , model.range , (NSInteger)j);
                    }
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.isTapEffect) {
        
        [self performSelectorOnMainThread:@selector(yb_tapEffectWithStatus:) withObject:nil waitUntilDone:NO];
        
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.isTapEffect) {

        [self performSelectorOnMainThread:@selector(yb_tapEffectWithStatus:) withObject:nil waitUntilDone:NO];
        
    }
}

- (CGAffineTransform)yb_transformForCoreText
{
    return CGAffineTransformScale(CGAffineTransformMakeTranslation(0, self.bounds.size.height), 1.f, -1.f);
}

- (CGRect)yb_getLineBounds:(CTLineRef)line point:(CGPoint)point
{
    CGFloat ascent = 0.0f;
    CGFloat descent = 0.0f;
    CGFloat leading = 0.0f;
    CGFloat width = (CGFloat)CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    CGFloat height = ascent + fabs(descent) + leading;
    
    return CGRectMake(point.x, point.y , width, height);
}

#pragma mark - tapEffect
- (void)yb_tapEffectWithStatus:(BOOL)status
{
    if (self.isTapEffect) {
        NSMutableAttributedString *attStr = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
        
        NSMutableAttributedString *subAtt = [[NSMutableAttributedString alloc] initWithAttributedString:[[self.effectDic allValues] firstObject]];
        
        NSRange range = NSRangeFromString([[self.effectDic allKeys] firstObject]);
        
        if (status) {
            [subAtt addAttribute:NSBackgroundColorAttributeName value:[UIColor lightGrayColor] range:NSMakeRange(0, subAtt.string.length)];
            
            [attStr replaceCharactersInRange:range withAttributedString:subAtt];
        }else {
            
            [attStr replaceCharactersInRange:range withAttributedString:subAtt];
        }
        self.attributedText = attStr;
    }
}

- (void)yb_saveEffectDicWithRange:(NSRange)range
{
    self.effectDic = [NSMutableDictionary dictionary];
    
    NSAttributedString *subAttribute = [self.attributedText attributedSubstringFromRange:range];
    
    [self.effectDic setObject:subAttribute forKey:NSStringFromRange(range)];
}

#pragma mark - getRange
- (void)yb_getRangesWithStrings:(NSArray <NSString *>  *)strings
{
    if (self.attributedText == nil) {
        self.isTapAction = NO;
        return;
    }
 
    self.isTapAction = YES;
    
    self.isTapEffect = YES;
    
    NSParagraphStyle *style = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:nil];
    
    if (!style || style.lineSpacing == 0) {
        
        NSMutableParagraphStyle *sty = [[NSMutableParagraphStyle alloc] init];
        
        sty.lineSpacing = 1;
        
        NSMutableAttributedString *attStr = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
        
        [attStr addAttribute:NSParagraphStyleAttributeName value:sty range:NSMakeRange(0, self.attributedText.string.length)];
        
        self.attributedText = attStr;
    }
    
    __block  NSString *totalStr = self.attributedText.string;
    
    self.attributeStrings = [NSMutableArray array];
    
    __weak typeof(self) weakSelf = self;
    
    [strings enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if (obj.length <= totalStr.length) {
            
            for (int i = 0 ; i < totalStr.length - obj.length + 1; i++) {
                
                NSString *rangeStr = [totalStr substringWithRange:NSMakeRange(i, obj.length)];
                
                if ([rangeStr isEqualToString:obj]) {
                    
                    YBAttributeModel *model = [YBAttributeModel new];
                    model.range = NSMakeRange(i, obj.length);
                    model.str = obj;
                    [weakSelf.attributeStrings addObject:model];
                    
                }
            }
        }
    }];
    
}

@end