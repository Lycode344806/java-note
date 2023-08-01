# IO

IO ： 用户内存-----操作系统内核内存------硬盘文件

指的是用户空间和内核空间数据交互的方式

## 同步IO

同步：用户空间要的数据，必须等到内核空间给它才做其他事情

## 异步IO

用户空间要的数据，不需要等到内核空间给它，才做其他事情。内核空间会异步通知用户进程，
并把数据

![1690169551157](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\1690169551157.png)

## 阻塞IO和非阻塞IO

### 同步阻塞IO（Blocking IO）

![1690169768001](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\1690169768001.png)

用户线程通过系统调用read发起IO读操作，由用户空间转到内核空间。内核等到数据包到达后，然后将
接收的数据拷贝到用户空间，完成read操作

```
{
    -- socket 阻塞
    read(socket, buffer);
    process(buffer);
}
```

### 同步非阻塞IO（Non-blocking IO）

![1690170053051](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\1690170053051.png)

```
{
    while(read(socket, buffer) != SUCCESS);
    process(buffer);
}
```

![Unix 的 5 种 IO 模型](http://static.iocoder.cn/images/Netty/2017_10_24/01.png)

![BIO、NIO、AIO 的流程图](http://static.iocoder.cn/images/Netty/2017_10_24/03.png)

![BIO 对比 NIO 对比 AIO](http://static.iocoder.cn/images/Netty/2017_10_24/02.png)



## IO多路复用（IO Multiplexing）

多路分离函数 select (操作系统)
用户首先将需要进行IO操作的socket添加到select中，然后阻塞等待select系统调用返回。当数据到
达时，socket被激活，select函数返回。用户线程正式发起read请求，读取数据并继续执行。

![1690170251593](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\1690170251593.png)

```
{
    select(socket);
    while(1)
    {
        --可用的
        sockets = select();  -- 阻塞
    	for(socket in sockets){ 
        	if(can_read(socket)){ 
            	read(socket, buffer);
            	process(buffer);
             } 
      }
  }
```

Reactor设计模式（反应器）

![1690170585595](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\1690170585595.png)

通过Reactor的方式，可以将用户线程轮询IO操作状态的工作统一交给handle_events事件循环进行处
理。用户线程注册事件处理器之后可以继续执行做其他的工作（异步），而Reactor线程负责调用内核
的select函数 检查socket状态。当有socket被激活时，则通知相应的用户线程（或执行用户线程的回调
函数），执行handle_event进行数据读取、处理的工作。由于select函数是阻塞的，因此多路IO复用模型也被称为异步阻塞IO模 型。注意，这里的所说的阻塞是指select函数执行时线程被阻塞，而不是指socket。一般在使用IO多路复用模型时，socket都是设置为NONBLOCK的，不过这并不会产生影响，因为用户发起IO请求时，数据已经到达了，用户线程 一定不会被阻塞。

```
void UserEventHandler::handle_event() {
if(can_read(socket))
{ read(socket, buffer);}}
```

异步IO（Asynchronous IO）

![1690170668569](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\1690170668569.png)

## Redis IO

### 多路复用技术以及epoll实现原理

Redis 是跑在单线程中的，所有的操作都是按照顺序线性执行的，但是由于读写操作等待用户输入或输
出都是阻塞的，所以 I/O 操作在一般情况下往往不能直接返回，这会导致某一文件的 I/O 阻塞导致整个进程
无法对它客户提供服务，而 I/O 多路复用就是为了解决这个问题而出现的

### IO多路复用实现机制

select，poll，epoll都是IO多路复用的机制。I/O多路复用就通过一种机制，可以监视多个描述符(fd---
socket)，一旦某个 描述符就绪，能够通知程序进行相应的操作。

#### select，poll :

在select/poll时代，服务器进程每次都把这100万个连接告诉操作系统(从用户态复制句柄数据结构到内
核态)让 操作系统内核去查询这些套接字(socket)上是否有事件发生，轮询完后，再将句柄数据复制到用户
态，让服务器应用程序轮询 处理已发生的网络事件，这一过程资源消耗较大，因此，select/poll一般只
能处理几千的并发连接。
epoll是poll的一种优化 , 返回后不需要对所有的fd进行遍历，在内核中维持了fd的列表

#### epoll的实现：

1）调用epoll_create()建立一个epoll对象(在epoll文件系统中为这个句柄对象分配资源)
2）调用epoll_ctl向epoll对象中添加这100万个连接的套接字
3）调用epoll_wait收集发生的事件的连接

#### redis epoll底层实现：

当某一进程调用epoll_create方法时，Linux内核会创建一个eventpoll结构体，这个结构体中有两个成
员与epoll的使用方式密切相关。

![1690268701643](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\1690268701643.png)每一个epoll对象都有一个独立的eventpoll结构体，用于存放通过epoll_ctl方法向epoll对象中添加进来
的事件。这些事件都会挂载在红黑树中，如此，重复添加的事件就可以通过红黑树而高效的识别出来(红黑树
的插入时间 效率是lgn，其中n为树的高度)。 而所有添加到epoll中的事件都会与设备(网卡)驱动程序建
立回调关系，也就是说，当相应的事件发生时会调用这个回调方法。这个回调方法在内核中叫
ep_poll_callback,它会将发生的事件添加到rdlist双链表中。
epoll_wait------> ep_poll-------> ep_poll_callback 将可用的socket放到rdlist里
epoll_wait 阻塞 当rdlist不为空时，epoll_wait 继续工作将 epitem放到rdlist中
socket 放到 event中 rdlist
在epoll中，对于每一个事件，都会建立一个epitem结构体，如下所示：

![1690268820929](C:\Users\Administrator\AppData\Roaming\Typora\typora-user-images\1690268820929.png)优势：

1. 不用重复传递。我们调用epoll_wait时就相当于以往调用select/poll，但是这时却不用传递socket
   句柄给内核，因为内核已经在epoll_ctl中拿到了要监控的句柄列表。
2. 在内核里，一切皆文件。所以，epoll向内核注册了一个文件系统，用于存储上述的被监控
   socket。当你调用 epoll_create时，就会在这个虚拟的epoll文件系统里创建一个file结点。当然这
   个file不是普通文件，它只服务于epoll。 epoll在被内核初始化时（操作系统启动），同时会开辟出epoll自己的内核高速cache区，用于安置每一个我们想监控的socket，这些socket会以红黑树的形式保存在内核cache里，以支持快速的查找、插入、删除。这 个内核高速cache区，就是建立连续的物理内存页，然后在之上建立slab层，简单的说，就是物理上分配好你 想要的size的内存对象，每次使用时都是使用空闲的已分配好的对
   象。
3. 极其高效的原因：
   这是由于我们在调用epoll_create时，内核除了帮我们在epoll文件系统里建了个file结点，在内核cache
   里建了个红黑树用于存储以后epoll_ctl传来的socket外，还会再建立一个list链表，用于存储准备就绪的事
   件，当epoll_wait调用时，仅仅观察这个list链表里有没有数据即可。有数据就返回，没有数据就
   sleep，等到timeout时间到后即使链表没数据也返回。所以，epoll_wait非常高效。

### IO多路复用实现机制2（芋艿版）

Redis 内部使用文件事件处理器 `file event handler`，这个文件事件处理器是单线程的，所以 Redis 才叫做单线程的模型。它采用 IO 多路复用机制同时监听多个 Socket，根据 Socket 上的事件来选择对应的事件处理器进行处理。

文件事件处理器的结构包含 4 个部分：

- 多个 Socket 。
- IO 多路复用程序。
- 文件事件分派器。
- 事件处理器（连接应答处理器、命令请求处理器、命令回复处理器）。

多个 Socket 可能会并发产生不同的操作，每个操作对应不同的文件事件，但是 IO 多路复用程序会监听多个 socket，会将 socket 产生的事件放入队列中排队，事件分派器每次从队列中取出一个事件，把该事件交给对应的事件处理器进行处理。

来看客户端与 redis 的一次通信过程：

![img](http://static.iocoder.cn/images/Redis/2019_11_22/01.png)

- 客户端 Socket01 向 Redis 的 Server Socket 请求建立连接，此时 Server Socket 会产生一个 `AE_READABLE` 事件，IO 多路复用程序监听到 server socket 产生的事件后，将该事件压入队列中。文件事件分派器从队列中获取该事件，交给`连接应答处理器`。连接应答处理器会创建一个能与客户端通信的 Socket01，并将该 Socket01 的 `AE_READABLE` 事件与命令请求处理器关联。
- 假设此时客户端发送了一个 `set key value` 请求，此时 Redis 中的 Socket01 会产生 `AE_READABLE` 事件，IO 多路复用程序将事件压入队列，此时事件分派器从队列中获取到该事件，由于前面 Socket01 的 `AE_READABLE` 事件已经与命令请求处理器关联，因此事件分派器将事件交给命令请求处理器来处理。命令请求处理器读取 Scket01 的 `set key value` 并在自己内存中完成 `set key value` 的设置。操作完成后，它会将 Scket01 的 `AE_WRITABLE` 事件与令回复处理器关联。
- 如果此时客户端准备好接收返回结果了，那么 Redis 中的 Socket01 会产生一个 `AE_WRITABLE` 事件，同样压入队列中，事件分派器找到相关联的命令回复处理器，由命令回复处理器对 socket01 输入本次操作的一个结果，比如 `ok`，之后解除 Socket01 的 `AE_WRITABLE` 事件与命令回复处理器的关联。

这样便完成了一次通信。😈 耐心理解一下，灰常重要。如果还是不能理解，可以在网络上搜一些资料，在理解理解。

## Netty线程模型
