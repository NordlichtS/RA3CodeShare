give your main menu a video background

10秒钟循环视频背景测试

Additional\Data\Movies 是视频目录

testv是用来测试的，可以无视。bgcrhistmas是本范例所显示的视频，尺寸应该为1280x720，30fps。

可以下载aptxml编辑器编辑feg_m_mainMenu3D.apt，下载链接：https://pan.baidu.com/s/1sIqLYC-ow4Bd44Ldr16LKw 
    提取码：rfyl 

apt可能需要更改的地方：

视频名称，对应Videos.xml里面的定义
    EASetStringVar "bgcrhistmas"

帧数，视频应该是30fps，300帧=10秒。如果视频长度不同这个数值可能略有变化，可进行微调。
    EAPushLong 300

ff.png 的内容是视频的最后一帧，用来填补视频播放延迟造成的1帧空白。
