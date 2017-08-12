//
//  ViewController.m
//  ZJSentenceAnalyzeDemo
//
//  Created by 张骏 on 17/8/2.
//  Copyright © 2017年 ZJ. All rights reserved.
//

#import "ViewController.h"
#import "Segmentor.h"
#import "BASentenceModel.h"

@interface ViewController ()
@property (nonatomic, strong) UITextField *textFieldA;
@property (nonatomic, strong) UITextField *textFieldB;
@property (nonatomic, strong) UIButton *analyzeBtn;
@property (nonatomic, strong) UILabel *resultLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *dictPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"iosjieba.bundle/dict/jieba.dict.small.utf8"];
    NSString *hmmPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"iosjieba.bundle/dict/hmm_model.utf8"];
    NSString *userDictPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"iosjieba.bundle/dict/user.dict.utf8"];
    
    const char *cDictPath = [dictPath UTF8String];
    const char *cHmmPath = [hmmPath UTF8String];
    const char *cUserDictPath = [userDictPath UTF8String];
    
    JiebaInit(cDictPath, cHmmPath, cUserDictPath);
    
    CGFloat padding = 30;
    CGFloat height = 50;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    
    _textFieldA = [[UITextField alloc] initWithFrame:CGRectMake(padding, 100, screenWidth - 2 * padding, height)];
    _textFieldA.font = [UIFont systemFontOfSize:30];
    _textFieldA.layer.borderColor = [UIColor grayColor].CGColor;
    _textFieldA.layer.borderWidth = 0.5;
    _textFieldA.placeholder = @"请输入第一个句子";
    _textFieldA.textColor = [UIColor blackColor];
    [_textFieldA setValue:[UIColor lightGrayColor] forKeyPath:@"_placeholderLabel.textColor"];
    
    [self.view addSubview:_textFieldA];

    _textFieldB = [[UITextField alloc] initWithFrame:CGRectMake(padding, CGRectGetMaxY(_textFieldA.frame) + padding, screenWidth - 2 * padding, height)];
    _textFieldB.font = [UIFont systemFontOfSize:30];
    _textFieldB.layer.borderColor = [UIColor grayColor].CGColor;
    _textFieldB.layer.borderWidth = 0.5;
    _textFieldB.placeholder = @"请输入第二个句子";
    _textFieldB.textColor = [UIColor blackColor];
    [_textFieldB setValue:[UIColor lightGrayColor] forKeyPath:@"_placeholderLabel.textColor"];
    
    [self.view addSubview:_textFieldB];

    _analyzeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _analyzeBtn.layer.borderColor = [UIColor grayColor].CGColor;
    _analyzeBtn.layer.borderWidth = 0.5;
    _analyzeBtn.frame = CGRectMake(padding, CGRectGetMaxY(_textFieldB.frame) + padding, screenWidth - 2 * padding, height);
    [_analyzeBtn setTitle:@"点击分析" forState:UIControlStateNormal];
    [_analyzeBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_analyzeBtn addTarget:self action:@selector(btnClicked) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:_analyzeBtn];

    
    _resultLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, CGRectGetMaxY(_analyzeBtn.frame) + padding, screenWidth - 2 * padding, height)];
    _resultLabel.font = [UIFont systemFontOfSize:20];
    _resultLabel.textAlignment = NSTextAlignmentCenter;
    _resultLabel.textColor = [UIColor blackColor];
    
    [self.view addSubview:_resultLabel];
}


- (void)btnClicked{

    NSString *stringA = _textFieldA.text;
    
    //结巴分词
    NSArray *wordsArrayA = [self stringCutByJieba:stringA];
    
    //构造一个句子对象
    BASentenceModel *sentenceA = [BASentenceModel sentenceWithText:stringA words:wordsArrayA];
    
    
    NSString *stringB = _textFieldB.text;
    
    //结巴分词
    NSArray *wordsArrayB = [self stringCutByJieba:stringB];
    
    //构造一个句子对象
    BASentenceModel *sentenceB = [BASentenceModel sentenceWithText:stringB words:wordsArrayB];
    
    //测试
    CGFloat percent = [self similarityPercentWithSentenceA:sentenceA sentenceB:sentenceB];
    _resultLabel.text = [NSString stringWithFormat:@"%f", percent];

//    CGFloat percent = [self similarPercentWithStringA:stringA andStringB:stringB];
//    _resultLabel.text = [NSString stringWithFormat:@"%f", percent];
}


/**
 结巴分词
 */
- (NSArray *)stringCutByJieba:(NSString *)string{
    
    if ([self isSentenceIgnore:string]) {
        
        NSMutableArray *tempArray = [NSMutableArray array];
        for (NSInteger i = 0; i < string.length; i++) {
            [tempArray addObject:[string substringWithRange:NSMakeRange(i, 1)]];
        }
        return tempArray.copy;
        
    } else {
        //结巴分词, 转为词数组
        const char* sentence = [string UTF8String];
        std::vector<std::string> words;
        JiebaCut(sentence, words);
        std::string result;
        result << words;
        
        NSString *relustString = [NSString stringWithUTF8String:result.c_str()].copy;
        
        relustString = [relustString stringByReplacingOccurrencesOfString:@"[" withString:@""];
        relustString = [relustString stringByReplacingOccurrencesOfString:@"]" withString:@""];
        relustString = [relustString stringByReplacingOccurrencesOfString:@" " withString:@""];
        relustString = [relustString stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        NSArray *wordsArray = [relustString componentsSeparatedByString:@","];
        
        return wordsArray;
    }
}


/**
 检查是不是纯数字
 */
- (BOOL)isSentenceIgnore:(NSString *)string{
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]];
    if(string.length > 0) {
        return NO;
    }
    return YES;
}


/**
 余弦夹角算法计算句子近似度
 */
- (CGFloat)similarityPercentWithSentenceA:(BASentenceModel *)sentenceA sentenceB:(BASentenceModel *)sentenceB{
    //计算余弦角度
    //两个向量内积
    //两个向量模长乘积
    __block NSInteger A = 0; //两个向量内积
    __block NSInteger B = 0; //第一个句子的模长乘积的平方
    __block NSInteger C = 0; //第二个句子的模长乘积的平方
    [sentenceA.wordsDic enumerateKeysAndObjectsUsingBlock:^(NSString *key1, NSNumber *value1, BOOL * _Nonnull stop) {
        
        NSNumber *value2 = [sentenceB.wordsDic objectForKey:key1];
        if (value2.integerValue) {
            A += (value1.integerValue * value2.integerValue);
        }
        
        B += value1.integerValue * value1.integerValue;
    }];
    
    [sentenceB.wordsDic enumerateKeysAndObjectsUsingBlock:^(NSString *key2, NSNumber *value2, BOOL * _Nonnull stop) {
        
        C += value2.integerValue * value2.integerValue;
    }];
    
    CGFloat percent = 1 - acos(A / (sqrt(B) * sqrt(C))) / M_PI;
    
    return percent;
}


//编辑距离分析法 中文不精确, 暂时未使用
- (CGFloat)similarPercentWithStringA:(NSString *)stringA andStringB:(NSString *)stringB{
    NSInteger n = stringA.length;
    NSInteger m = stringB.length;
    if (m == 0 || n == 0) return 0;

    //Construct a matrix, need C99 support
    NSInteger matrix[n + 1][m + 1];
    memset(&matrix[0], 0, m + 1);
    for(NSInteger i=1; i<=n; i++) {
        memset(&matrix[i], 0, m + 1);
        matrix[i][0] = i;
    }
    for(NSInteger i = 1; i <= m; i++) {
        matrix[0][i] = i;
    }
    for(NSInteger i = 1; i <= n; i++) {
        unichar si = [stringA characterAtIndex:i - 1];
        for(NSInteger j = 1; j <= m; j++) {
            unichar dj = [stringB characterAtIndex:j-1];
            NSInteger cost;
            if(si == dj){
                cost = 0;
            } else {
                cost = 1;
            }
            const NSInteger above = matrix[i - 1][j] + 1;
            const NSInteger left = matrix[i][j - 1] + 1;
            const NSInteger diag = matrix[i - 1][j - 1] + cost;
            matrix[i][j] = MIN(above, MIN(left, diag));
        }
    }

    CGFloat percent = 1.0 - (CGFloat)matrix[n][m] / stringA.length;
    if (percent > 1) {
        percent = 0;
    }

    return MAX(percent, 0);
}

@end
