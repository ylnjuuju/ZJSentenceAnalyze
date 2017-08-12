## 引言 
```
技术无关, 可跳过.

最近在写一个独立项目, 
基于斗鱼直播平台的开放接口, 对斗鱼的弹幕进行实时的分析,
最近抽空记录一下其中一些我个人觉得值得分享的技术.

在写这个项目的时候我一直在思考, 弹幕这种形式已经出来了很久,
而且被广大网友热爱, 确实增强了参与者之间的沟通, 
但近年弹幕的形式却没什么很大的创新, 而问题却有许多,
其中有一条弹幕非常多的时候, 其实很多是重复的, 非常影响观感.

于是我提出了一个需求: 实时采集弹幕, 并相互之间对比,
合并相近的弹幕, 这里的"相近"是个什么样的标准就是值得去思考的一个东西了.

在查阅了很多资料之后, 发现这里已经到了一个对自然语言处理的问题,
说大一点属于AI的范畴了, 各大云平台例如腾讯云都有这方面的功能,
苹果最近WWDC发布的CoreML就可以使用训练好的自然语言识别模型.
在还不能用到CoreML(性能问题有待斟酌)之前,
连接云平台在瞬间高并发的使用场景下是不太现实的,
所以需要本地算出两个中文句子的"语义近似度".

```
## 理论
#### 编辑距离算法:
```
编辑距离，又称Levenshtein距离，是指两个字串之间，
由一个转成另一个所需的最少编辑操作次数。
许可的编辑操作包括将一个字符替换成另一个字符，插入一个字符，删除一个字符。
每个操作成本不同, 最终可以得到一个编辑距离.
编辑距离越短, 句子就越相似, 编辑距离越长, 句子相似度就越低.

这种算法很早就被提出来了, 而且网上资料非常齐全, 先看算法:
```

```
#import "NSString+Distance.h"
static inline int min(int a, int b) {
    return a < b ? a : b;
}

@implementation NSString (Distance)
- (float)SimilarPercentWithStringA:(NSString *)stringA andStringB:(NSString *)stringB{
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
    return 100.0 - 100.0 * matrix[n][m] / stringA.length;
}
@end
```

```
实际测试起来, 这种算法由于对中文的适应性不好, 会有各种问题, 不细说了.
继续查资料, 看到另一种算法.
```

#### 词频向量余弦夹角算法:
```
这种算法思想也挺简单的,
将两个句子构造成两个向量, 并计算这两个向量的余弦夹角cos(θ),
夹角为0°, 则代表两个句子意思完全相同,
夹角为180°, 则代表两个句子相似度为零.

下一个问题, 怎样将句子构造成向量?
这里就引入"词频向量",
简单的说就是先将两个句子分词,
通过词第一次出现的位置以及词出现的频率组成向量,
再计算夹角.

举个例子:
句子A: 斗鱼伴侣真是有意思,支持斗鱼直播
句子B: 斗鱼伴侣挺有意思,斗鱼直播可以用

分词之后:
句子A: 斗鱼/伴侣/真是/有意思/支持/斗鱼/直播
句子B: 斗鱼/伴侣/挺/有意思/斗鱼/直播/可以/用

向量:
句子A:[2(斗鱼),1(伴侣),1(真是),1(有意思),1(支持),1(直播)] (斗鱼出现2次, 其他出现1次)
句子B:[2(斗鱼),1(伴侣),1(挺),1(有意思),1(直播),1(可以),1(用)] (同上)


先看下面公式

```

![](http://osnabh9h1.bkt.clouddn.com/17-8-2/69096512.jpg)
```
分子就是2个向量的内积
ab = 2x2(斗鱼) + 1x1(伴侣) + 1x0(真是) + 1x0(挺) + 1x1(有意思) + 1x0(支持) + 1x1(直播) + 1x0(可以) + 1x0(用)
   = 7

分母是两个向量的模长乘积
||a|| = sqrt(2x2(斗鱼) + 1x1(伴侣) + 1x1(真是) + 1x1(有意思) + 1x1(支持) + 1x1(直播))
      = 3

||b|| = 2x2(斗鱼) + 1x1(伴侣) + 1x1(挺) + 1x1(有意思) + 1x1(直播) + 1x1(可以) + 1x1(用)
      = 3.16....
      
最终可以得出来
cos θ = 0.737865

其实到此为止基本上可以判断出这两个句子的相似度了,
换算成角度其实更精确
similarity = arccos(0.737865) / M_PI 
           = 0.764166
           
参考文章: https://mp.weixin.qq.com/s/dohbdkQvHIGnAWR_uPZPuA
```

## 实际
```
下面具体说说这套算法思想的实现
这里面实际用起来有两个难点:
1.分词: iOS系统其实自带分词Api, 只是对中文的支持并不是那么友好,
        而且在高并发的情况下性能也堪忧, 自定义词库那是更加不能实现的了. 
2.构造向量并计算: 这个其实在iOS中直接构造向量也是不那么好实现的,
                因为涉及到两个句子词的对比, 需要补0.

```

#### 分词
```
这里感谢开源的分词库 结巴分词
这个库有各个语言的版本 其中iOS的版本地址:
https://github.com/yanyiwu/iosjieba

集成以及使用起来也非常简单, 性能也非常不错(苹果自带甩分词不见了)
库的底层是C++, 所以只是要注意的是用到库的文件改为.mm后缀名.

结巴分词支持自定义词库 直接将词写入下面文件
注意不能空行 否则会报错
iosjieba.bundle/dict/user.dict.utf8

具体词哪里来...
用抓包软件在某些输入法中抓的= =.. 
```
```
//初始化后直接使用
- (void)loadJieba{
    NSString *dictPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"iosjieba.bundle/dict/jieba.dict.small.utf8"];
    NSString *hmmPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"iosjieba.bundle/dict/hmm_model.utf8"];
    NSString *userDictPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"iosjieba.bundle/dict/user.dict.utf8"];
    
    const char *cDictPath = [dictPath UTF8String];
    const char *cHmmPath = [hmmPath UTF8String];
    const char *cUserDictPath = [userDictPath UTF8String];
    
    JiebaInit(cDictPath, cHmmPath, cUserDictPath);
}


//字符串转词数组
- (NSArray *)stringCutByJieba:(NSString *)string{
    
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
```

#### 计算
```
上面已经解决了分词的问题, 下面说说具体怎么算,
这里我没有直接构造向量解决, 并没有太好的思路.
但是利用算法的思路和面向对象的思想我是这样解决的:

我们需要得到的是向量的内积和模长乘积,
先说模长乘积, 这个数字是固定的, 跟对比的句子无关, 比较好得到.
我们发现向量的内积其实在这里跟词的位置无关, 
所以可以用字典来构造, key为词, value为词频, 
遍历数组对比, 可以得到每个词的词频, 构造词频字典,
再将两个字典相同key的value相乘即为模长乘积.

说起来有点绕, 看代码:
```

```
这里构造了两个BASentenceModel用来存原来的文本,分词后的词数组,以及词频字典.

在设置分词数组时候遍历数组得出词频
- (void)setWordsArray:(NSArray *)wordsArray{
    _wordsArray = wordsArray;
    
    //根据句子出现的频率构造一个字典
    __block NSMutableDictionary *wordsDic = [NSMutableDictionary dictionary];
    [wordsArray enumerateObjectsUsingBlock:^(NSString *obj1, NSUInteger idx1, BOOL * _Nonnull stop1) {
        
        //若字典中已有这个词的词频 +1
        if (![[wordsDic objectForKey:obj1] integerValue]) {
            __block NSInteger count = 1;
            [wordsArray enumerateObjectsUsingBlock:^(NSString *obj2, NSUInteger idx2, BOOL * _Nonnull stop2) {
                if ([obj1 isEqualToString:obj2] && idx1 != idx2) {
                    count += 1;
                }
            }];
            
            [wordsDic setObject:@(count) forKey:obj1];
        }
    }];
    _wordsDic = wordsDic;
}


传入两个句子对象即可得出两个句子之间的近似度

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
```

##### 结论
![](http://osnabh9h1.bkt.clouddn.com/17-8-12/29442098.jpg)
```
我知道很多人觉得这个挺没有意义的,毕竟没有人在前端上做这些事情..
但实际效果确实不错, 在高峰弹幕期间弹幕合并大于1000+.
这里用的iphone6测试, 30秒1500条弹幕, 分词就可以分成6000+,
再进行各种分析(活跃度, 等级, 词频, 句子, 礼物统计, 筛选等等等), 
这种强度下的计算, iphone完全无问题, 多线程处理好之后如下图:
```
![](http://osnabh9h1.bkt.clouddn.com/17-8-12/65774450.jpg)
```
相对于服务器高度依赖于数据库计算, 受制于数据库与硬盘性能来说,
内存中的读写显然更有优势, 问题其实在ARC的情况下内存的释放不太受控制,
非常多弹幕的情况下可能会告警, 不过也只能这样了.
毕竟海量弹幕模式PC打开浏览器仅作展示都会卡死...

另一方面AI计算放在移动设备上可能也是一种趋势,
苹果推出CoreML希望在兼顾隐私的同时,让随身设备更智能, 
想象一下全球的手机都有AI系统独立计算各种数据, 数据存在云中再一次处理,
这会是一个很近而且很爆炸的未来.


以上.
题外话:App已上架, 名字叫:斗鱼伴侣, 功能点还挺多的
其中绘图(quartz2D),动画(CoreAnimation/lottie)运用的都挺多的.
感觉大家会有兴趣, 有需要可以写写经验.
App大家可以下下来看看, 顺便给个好评, 3Q!
```
