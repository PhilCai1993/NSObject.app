---
date: 2022-06-19 13:18
description: 在iOS中运行Ruby
tags: iOS
---
# 在iOS中运行Ruby(mruby 简介)


iOS上执行[JS](https://developer.apple.com/documentation/javascriptcore)、[Lua](https://github.com/alibaba/LuaViewSDK)、[Python](https://bytekm.bytedance.net/kmf/articleDetail/391)的案例已经很多了，好像很少有人分享Ruby。

[mruby](http://mruby.org/)是一个专门为嵌入式设计的Ruby,  作者是ruby的作者([Matz](https://en.wikipedia.org/wiki/Yukihiro_Matsumoto))本人.  在它的[GitHub](https://github.com/mruby/mruby)上说明它支持Ruby 1.9 的语法, 实际上2.x的语法也部分支持.

## 诞生背景
> 拿当前的 Ruby (CRuby)来说, 预想的架构是”使用 Ruby 来开发应用程序. 如果遇到缺失的功能, 就使用 C 语言开发扩展程序库, 然后添加到 Ruby 中”. 换言之, 以从属关系来看, 是 Ruby 为主, C 为辅的关系. 然而, 这与嵌入式软件中常见的“使用 C/C++ 开发程序, 而仅把需要灵活性或生产效率的那部分交给 Ruby”的架构不符.  

根据作者的介绍, mruby 是一个轻量、极简的CRuby的子集. 定位是嵌入式, 以C(C++/ObjC) 为主, mruby为辅, 负责一些灵活多变的功能.

和同样强大的Lua相比, Ruby开发者的数量更多(个人感觉Ruby写起来爽一点).

至于为什么现在看起来还是Lua/JS 满天飞, mruby 少有人提…

![](/Images/mruby_1.png)


## mruby目录结构
以目前最新的[mruby 2.0.1 released](http://mruby.org/releases/2019/04/04/mruby-2.0.1-released.html)为例.
![](/Images/mruby_2.png)


* benchmark: 性能测试
* bin: mruby 实现的几个工具
    * mirb: 相当于日常用的 irb  (Interactive Ruby)
    * mrbc: 编译器, 可以将ruby代码编译成中间代码(.mrb 格式)
    * mruby: 相当于ruby command line
    * mruby-strip: 大概是用来清除ruby编译产物的符号的
* build: 编译产物的输出路径
* examples: 一些C & mruby 交互的demo
* include: 头文件
* lib: 一些mruby的基础功能
* mrbgems: 同ruby gems
* mrblib: mruby 的基础类型的声明或者实现(ruby)
* src: mruby的核心实现(C)
* tasks: toolchain(一堆rakefile)
* test: 测试…
* minirake: 精简版rake
* build_config.rb: 类似CocoaPods 的podspec, 描述如何编译一个对应平台的二进制(比如可以嵌入到iOS的libmruby.a/MRuby.framework, Android 当然也可以)


## 编译iOS静态库(.a)
将 *build_config.rb* 替换为如下:
```ruby
#build_config.rb
MRuby::Build.new do |conf|
  toolchain :clang
  conf.gembox "default"
end

def crossbuild(arch, ios_sdk, min_version = "8.0.0")
  MRuby::CrossBuild.new(arch) do |conf|
    toolchain :clang
    conf.gembox "default"
    conf.bins = []

    conf.cc do |cc|
      cc.command = "xcrun"
      cc.defines = ["MRB_INT64"] /#mrb_int 使用 int64_t/
      cc.flags = %W(-sdk iphoneos clang -miphoneos-version-min=#{min_version} -arch #{arch} -isysroot #{ios_sdk} -fembed-bitcode)
    end

    conf.linker do |linker|
      linker.command = "xcrun"
      linker.flags = %W(-sdk iphoneos clang -miphoneos-version-min=#{min_version} -arch #{arch} -isysroot #{ios_sdk})
    end

    conf.build_mrbtest_lib_only
    conf.test_runner.command = "env"
  end
end

SIM_SDK_PATH = %x[xcrun --sdk iphonesimulator --show-sdk-path].strip
DEVICE_SDK_PATH = %x[xcrun --sdk iphoneos --show-sdk-path].strip
MIN_VERSION = "9.0.0"

#crossbuild

crossbuild("x86_64", SIM_SDK_PATH, MIN_VERSION)
crossbuild("arm64", DEVICE_SDK_PATH, MIN_VERSION)
crossbuild("armv7", DEVICE_SDK_PATH, MIN_VERSION)
# 有需要可以加个i386 的
```



然后在*build_config.rb* 的目录下, 执行 `./minirake`, 如果没问题会在build目录下生成 一个host 目录, 以及x86_64 & arm64 & armv7 目录(对应`CrossBuild`的声明). 在`$arch/lib`可以看到有`libmruby_core.a`,`libmruby.a`, lipo 合并一下, 可以拖到Xcode project使用(需要修改一部分include).

![](/Images/mruby_3.png)

## 编译静态framework
为了让Swift也可以和mruby 交互,  需要尝试将上面的`.a`打包成framework.
在上一步的`minirake`成功后, 和*build_config.rb*同一级新建一个*build_framework.rb*. 

```ruby
#build_framework.rb
require "FileUtils"

SCRIPT_PATH = File.dirname(__FILE__)
BUILD_PATH = File.join(SCRIPT_PATH, "build")
FRAMEWORK_TARGET_PATH = File.join(BUILD_PATH, "MRuby.framework")
FRAMEWORK_HEADERS_DIR = File.join(FRAMEWORK_TARGET_PATH, "Headers")
SOURCE_HEADERS_DIR = File.join(SCRIPT_PATH, "include")
LIB_FILES = %w(x86_64 armv7 arm64).map do |arch|
    File.join(SCRIPT_PATH, "build", arch, "lib/libmruby.a")
end

FileUtils.rm_rf FRAMEWORK_TARGET_PATH
FileUtils.mkdir_p FRAMEWORK_HEADERS_DIR
FileUtils.cp_r "#{SOURCE_HEADERS_DIR}/mruby.h", "#{FRAMEWORK_HEADERS_DIR}/mruby_renamed.h"
FileUtils.cp_r "#{SOURCE_HEADERS_DIR}/mrbconf.h", FRAMEWORK_HEADERS_DIR
FileUtils.cp_r "#{SOURCE_HEADERS_DIR}/mruby/.", FRAMEWORK_HEADERS_DIR

Dir.glob("#{FRAMEWORK_HEADERS_DIR}/*.h").each do |file|
  replaced = File.read(file).gsub(/^#include "mruby\/(.+)"$/, '#include "\1"').gsub(/^#include <mruby\.h>$/, '#include "mruby_renamed.h"').gsub(/^#include <mruby\/(.+)>$/, '#include "\1"')
  File.open(file, "w") { |f| f.puts replaced }
end

File.open "#{FRAMEWORK_HEADERS_DIR}/MRuby.h", "w" do |file|
  file.puts "#define MRB_INT64"
  file.puts '#include "mruby_renamed.h"'
  Dir.chdir "#{FRAMEWORK_HEADERS_DIR}" do
    Dir["*.h"].each do |f|
      next if f == "mruby/debug.h"
      next if f == "boxing_nan.h"
      next if f == "boxing_no.h"
      next if f == "boxing_word.h"
      next if f == "ops.h"
      next if f == "opcode.h"
      next if f == "mruby_renamed.h"
      next if f == "mrbconf.h"
      next if f == "MRuby.h"
      file.puts "#include \"#{f}\""
    end
  end
end

Dir.mkdir "#{FRAMEWORK_TARGET_PATH}/Modules"
  File.open "#{FRAMEWORK_TARGET_PATH}/Modules/module.modulemap", "w" do |file|
    file.write <<EOF
framework module MRuby {
  umbrella header "MRuby.h"

  exclude header "boxing_nan.h"
  exclude header "boxing_no.h"
  exclude header "boxing_word.h"
  exclude header "debug.h"

  export *
  module * { export * }
}
EOF
end

system "lipo #{LIB_FILES.join " "} -create -output #{FRAMEWORK_TARGET_PATH}/MRuby"
```

脚本的主要作用是
1. 将*include*目录下的各个`.h`平铺到同一层
2. 修正一部分`#include`
3. 将原先的*mruby.h*重命名, 防止和最终的*MRuby.framework*冲突.
4. 配置一下*modulemap*

执行`./minirake && ruby build_framework.rb`之后, 在*build* 目录下就有一个*MRuby.framework*.

![](/Images/mruby_4.png)





## 参考
- [LLVM的 Modules ](https://www.stephenw.cc/2017/08/23/llvm-modules/).
- [关于mruby的一切](http://www.ituring.com.cn/book/1339)
- [GitHub - stephenwzl/RubyCore: ruby core runtime wrapper for Objective-C & CocoaTouch](https://github.com/stephenwzl/RubyCore)
