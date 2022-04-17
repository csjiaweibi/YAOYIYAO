
;波特率9600
;---------------------------------------
        ORG 0000H
        LJMP MAIN
;--------------------------------------
;位定义		
        LCMRS  bit  P2.6
        LCMRW  bit  P2.5
        LCMEN  bit  P2.7
		LCMDATA EQU P0

;---------------------------------------
;中断入口地址分配

        ORG  000BH
        LJMP TIMO      ;定时器T0中断入口地址（倒计时用定时器中断）
        ORG  0003H
		LJMP CLEAR
		ORG  0013H
        LJMP JISHU     ;外部中断1(计数程序),P3.3
		ORG  0023H
		LJMP RECEIVE   ;串口中断

;------------------------------------
CLEAR:	   ;打开外部中断0
        //PUSH ACC				
        MOV  R0,#00H ;清空计数值
		MOV  30H,#0   ;存放摇一摇次数的五个位置的数据初始化
		MOV  31H,#0 
		MOV  32H,#0 
		MOV  33H,#0
		MOV  34H,#0
		LCALL SHOWTIME1

		//POP  ACC     	
		RETI

;---------------------------------------
RECEIVE:	           ;串口中断子程序
    CLR RI
    MOV A,SBUF          
    MOV 5FH,A		   ;秒数存入5FH
	MOV 61H,5FH		   ;秒数存入61H
	LCALL SHOWTIME
    MOV SBUF,A           
    JNB TI,$
    CLR TI
	CLR ES
    RETI

;---------------------------------------
TIMO:
PUSH ACC
MOV TH0,#0D8H
MOV TL0,#0F0H
DJNZ 60H,TT1
MOV 60H,#100
DEC 61H
LCALL SHOWTIME
MOV A,61H
JNZ TT1
MOV 61H,5FH
SETB 4FH
TT1:
POP ACC
RETI
;---------------------------------------
;外部中断1 摇一摇程序代码
JISHU:  			       ;对中断进行累加计数 
     CLR EX1
	 LCALL  DELAY 	      
	 INC    @R0	
	 LCALL  SEND	   ;串口实时输出结果
	 SETB EX1			  
	 RETI
;---------------------------------------
;主函数
        ORG  0100H
MAIN:   ;初始化
        //LCALL UP
        MOV  30H,#0   ;存放摇一摇次数的五个位置的数据初始化
		MOV  31H,#0 
		MOV  32H,#0 
		MOV  33H,#0
		MOV  34H,#0
		MOV  R4 ,#5		;设置排序监测个数为5
		MOV  R0 ,#30H 
		MOV  SP ,#60H     

        MOV  SCON ,#50H  ;设定串行方式： 8 位异步， 允许接收
        MOV  TMOD ,#21H  ;设定计数器 1 为模式2 
        //MOV  PCON ,#80H  ;波特率加倍
        MOV  TH1,  #0FDH ;9600
        MOV  TL1,  #0FDH ;
		MOV  TH0,  #0D8H
        MOV  TL0,  #0F0H
        
		SETB EX0
		SETB ET0 ;打开定时器T0中断
		SETB PX0
		SETB PX1 ;设置外部中断1为高优先级
        //CLR  PT0 ;设置定时器T0中断为低优先级
        CLR  IT1 ;设置外部中断1 触发方式为低电平触发
	    CLR  IT0
// SETB TR0 ;打开串口输入波特率定时器
//SETB EX1 ;打开外部中断1		 
        SETB EA	 ;打开中断允许总控制位

MOV 5FH,#00H
MOV 64H,#00H
MOV SP,#70H
LCALL LCMSET
LCALL LCMCLR
MOV A,#80H
LCALL LCMWR0
MOV DPTR,#TAB0
LCALL SHOW1
MOV A,#0C0H
LCALL LCMWR0
MOV DPTR,#TAB1
LCALL SHOW1

MOV 60H,#100
MOV 61H,5FH
CLR 4FH  
      
SETB EA               
SETB ES               
SETB TR1              
MOV A,5FH



;------------------------------------------------------
; 设置独立按键作用

wait:		 ;p3.2   开启倒计时  卡在这里卡住五次才行
JNZ key1
MOV A,5FH  
LJMP wait

key1:
jnb p3.1,s1ok 
JMP key1

SJMP $

s1ok:
MOV A,#80H
LCALL LCMWR0
MOV DPTR,#TAB3
LCALL SHOW1
SETB EX1 		  ;打开外部中断允许控制位
LCALL SHOWTIME 
SETB TR0
SETB EX1

TT: 
JNB 4FH,TT
CLR TR0
CLR 4FH
INC R0	;指向下一个地址
CLR EX1
DJNZ R4,key1  
	    
;-----------------------------------------------------
key2:	  ;p3.2   该按键用于调用五位地址排序子程序  
          ;排序程序结束在串口按次序显示五个地址的（代号？比如12345吧）
jnb p3.0,SORTSHOW	   ;p3.2   
LJMP key2
	   
LJMP  wait	 
			
;-----------------------------
;串口输出排序结果子程序	(可能需要修改)
SORTSHOW:
MOV A,#80H
LCALL LCMWR0
MOV DPTR,#TAB4
LCALL SHOW1	  
MOV  IE,#0
MOV  A,#0 
MOV  SP,#60H	
MOV SCON,#0D0H
MOV PCON,#80H
MOV TMOD,#21H
MOV PCON,#80H  
MOV TL1,#0FAH
MOV TH1,#0FAH  	  
SETB TR1
mov R4,#5
mov R0,#30H
SORT:    
        MOV R6,#5  ;外层循环次数
        MOV R7,#5  ;内层循环次数
        MOV R0,#30H

LOP0:   MOV R7,#5 ;
        MOV R0,#30H

LOP1:   MOV A,@R0
        INC R0
        MOV B,@R0  ;此时AB为前后两个数
        CJNE A,B,COM  ;比较不相等转移

COM:              ;判断是否交换
	    JNC NEXT  ;如果前面的数（A中的）大，则CY=0，否则CY=1，因此在程序转移后再次利用CY就可判断出A中的数比data大还是小了。
  	    XCH A,B   ;开始交换
	    DEC R0
	    MOV @R0,A
	    INC R0
	    MOV @R0,B
	    JMP NEXT

NEXT: 
        DJNZ R7,LOP1 ;判断外层循环次数
        DJNZ R6,LOP0 ;判断外层循环趟数，外层循环完一趟，R0重新定位到最前面的数据，且R6归7
       // LCALL ;串口输出排序结果
		MOV R0,#30H
	LCALL trs
trs:	 ;串口输出子程序
MOV   A ,@R0
MOV   SBUF ,A
WAI: JBC TI,CONT
     SJMP WAI
CONT:INC R0
     DJNZ R4,trs
     SJMP $
	 RET
	         
;----------------------------------------
;串口发送数据子程序
SEND:	  
		  SETB TR1
          LCALL  DELAY1      
          MOV   A,@R0
          MOV   SBUF, A
     	  CLR TI
		  CLR TR1
		  RET

MOV  SCON ,#50H  ;设定串行方式： 8 位异步， 允许接收
MOV  TMOD ,#21H  ;设定计数器 1 为模式2 
        //MOV  PCON ,#80H  ;波特率加倍
MOV  TH1,  #0FDH ;9600
MOV  TL1,  #0FDH ;  
;--------------------------------
SHOWTIME:
PUSH ACC
MOV A,#0C9H
LCALL LCMWR0
MOV R1,#61H		 
LCALL HASC
LCALL SHOW2
POP ACC
RET 
SHOWTIME1:
PUSH ACC
MOV A,#0C9H
LCALL LCMWR0

MOV A,#' '                            
LCALL LCMLAY
CLR LCMEN
SETB LCMRS
CLR LCMRW
SETB LCMEN
MOV LCMDATA,A
CLR LCMEN
RET		 
LCALL HASC
LCALL SHOW2
POP ACC
RET 
;---------------------------------------
;10ms延时 可用于按键消抖
/*DLY:        MOV  R6, #20            
     D11:    MOV  R7, #248
            DJNZ R7, $
            DJNZ R6, D11
            RET*/
;---------------------------------------

;--------------------------------------------------------------------------------
DELAY1:			       	  ;延时程序，用于摇一摇消抖
            MOV R6,#100
   D11:     MOV R5,#255   
   D22:     DJNZ R5,D22   
            DJNZ R6,D11   
            RET	

;-----------------------------------					
TAB0: DB "Set Time Please",00H
TAB1: DB "Time Is:   s",00H
TAB3: DB "Shake It Quick!",00H
TAB4: DB "Show The Sort!",00H
HASC: 
PUSH ACC
MOV A,@R1       
MOV B,#10
DIV AB
SWAP A
ADDC A,B
MOV B,A 
ANL A,#0FH 
ADD A,#90H
DA A
ADDC A,#40H
DA A
XCH A,B 
SWAP A 
ANL A,#0FH 
ADD A,#90H
DA A
ADDC A,#40H
DA A
MOV 62H,A
MOV 63H,B
INC R1     
POP ACC
RET

LCMLAY:                                   
PUSH ACC
LOOP:
CLR LCMEN
CLR LCMRS
SETB LCMRW
SETB LCMEN
MOV A,LCMDATA
CLR LCMEN
JB ACC.7,LOOP
POP ACC
LCALL DELAY
RET

LCMWR0:                                  
LCALL LCMLAY
CLR LCMEN
CLR LCMRS
CLR LCMRW
SETB LCMEN
MOV LCMDATA,A
CLR LCMEN
RET

LCMWR1:                              
LCALL LCMLAY
CLR LCMEN
SETB LCMRS
CLR LCMRW
SETB LCMEN
MOV LCMDATA,A
CLR LCMEN
RET


SHOW1:             ;表格写入方式               
PUSH ACC
LOOP3:
CLR A
MOVC A,@A+DPTR
JZ LOOP4
LCALL LCMWR1
INC DPTR
LJMP LOOP3
LOOP4:
POP ACC
RET

SHOW2:               ;数字写入方式            
PUSH ACC
LOOP1:
CLR A
MOV A,@R1
JZ LOOP2
LCALL LCMWR1
INC R1
LJMP LOOP1
LOOP2:
POP ACC
RET

LCMSET:                            
MOV A,#38H
LCALL LCMWR0
MOV A,#08H
LCALL LCMWR0
MOV A,#01H
LCALL LCMWR0
MOV A,#06H
LCALL LCMWR0
MOV A,#0CH

LCALL LCMWR0
RET

LCMCLR:                             
MOV A,#01H
LCALL LCMWR0
RET

DELAY:
MOV R6,#5           
D1:  MOV R7,#248
DJNZ R7,$
DJNZ R6,D1
RET

END
