.386 

option casemap:none

;очень нужная библиотека, для взаимодействия с файловой системой
INCLUDE Irvine32.inc


;Вход: e,z,y,sum
;Выход: ecx =  (((z>>5)^(y<<2))+((y>>3)^(z<<4)))^((sum^y)+(k[(p&3)^e]^z))

MX macro e, z, y, sum
    mov     ecx , [z]
    shr     ecx , 5         ; z>>5
    mov     edx , [y]
    shl     edx , 2         ; y<<2
    xor     ecx , edx       ; вычислили (z>>5)^(y<<2)
    mov     eax , [y]
    shr     eax , 3         ; y>>3
    mov     edx , [z]
    shl     edx , 4         ; z<<4
    xor     eax , edx       ; вычислили (y>>3)^(z<<4)
    add     ecx , eax       ; вычислили ((z>>5)^(y<<2))+((y>>3)^(z<<4))
    mov     eax , [sum]
    xor     eax , [y]       ; вычислили (sum^y)
    mov     edx , [p]
    and     edx , 3         ; вычислили (p&3)
    xor     edx , [e]       ; (p&3)^e
    mov     esi , offset key
    mov     edx , [esi+edx*4] ; edx = k[(p&3)^e]
    xor     edx , [z]         ; k[(p&3)^e]^z
    add     eax , edx         ; (sum^y)+(k[(p&3)^e]^z)
    xor     ecx , eax         ; ((z>>5)^(y<<2))+((y>>3)^(z<<4)))^((sum^y)+(k[(p&3)^e]^z)) 
endm

.const

BUFFER_SIZE     equ     65535   ; ограничим максимальный размер входных данных 65535 байтами
DELTA           equ     -1640531527 ; DELTA 

.data

key             BYTE    16          DUP(0)  ;   буффер для H_i-1
x               BYTE    16          DUP(0)  ;   буффер для x_i
data            BYTE    BUFFER_SIZE DUP(0)  ;   буффер входных данных


inputFileName   BYTE    "input",0   ; определим название файла с входными данными
keyFileName     BYTE    "key",0     ; имя файла с ключом
outputFileName  BYTE    "output",0  ; название файла для записи вычислений


error           BYTE        0       ; переменна для мониторинга за ошибками во время работы с файловой системой. если error != 0 произошла ошибка
bytesRead       DWORD       0       ; количество прочитанных байт
bytesWritten    DWORD       16      ; количество записанных байт
blocksCount     DWORD       0       ; количество прочитанных блоков

;ниже перечислены различные ошибки
fileCreateError     BYTE    "Error: failed to create file",0dh,0ah,0
fileOpenError       BYTE    "Error: failed to open file",0dh,0ah,0
BadKeyError         BYTE    "Error: key length is wrong",0dh,0ah,0
dataError           BYTE    "Error: data file is empty",0dh,0ah,0

.code

XxteaEncode     PROC uses ebx v: DWORD, n:DWORD
    LOCAL y : DWORD
    LOCAL z : DWORD
    LOCAL sum : DWORD
    LOCAL p : DWORD
    LOCAL rounds: DWORD
    LOCAL e : DWORD

	;количество раундов определяется по формуле 6+52/n
    .if [n] > 52
        mov [rounds] , 6        ; если n>52 тогда (52/n < 1) => можно отбросить это слагаемое
    .else
        mov     ecx , 6
        mov     eax , 52
        mov     ebx , [n]
        and     ebx , 0ffh
        div     bl
        add     cl , al
        xor     eax , eax
        mov     al , cl
        mov     rounds , eax    ; вычислили количество раундов
    .endif

    mov     [sum] , 0           ; sum = 0

    mov     eax , [n]
    dec     eax
    mov     ecx , [v]
    mov     edx , [ecx+eax*4]
    mov     [z] , edx           ; z=v[n-1]

mainLoop:
    mov     eax , [sum]
    add     eax , DELTA
    mov     [sum] , eax             ; sum += DELTA
    shr     eax , 2
    and     eax , 3
    mov     [e] , eax               ; e = (sum >> 2) & 3
    mov     [p] , 0                 ; p = 0
    jmp     short   innerLoop
mainLoopBody1:
    inc dword ptr [p]
innerLoop:
    mov     eax , [n]
    dec     eax
    cmp     [p] , eax
    jae     mainLoopBody2
    mov     ecx, [p]
    inc     ecx
    mov     edx, [v]
    mov     eax, dword ptr [edx+ecx*4]
    mov     dword ptr [y], eax              ; y = v[p+1]
    MX e, z, y, sum
    mov     eax , [p]
    mov     edx , [v]
    mov     ebx, dword ptr [edx+eax*4]
    add     ebx, ecx
    mov     dword ptr [edx+eax*4] , ebx     ; v[p] += MX
    mov     [z] , ebx                       ; z = v[p]
    jmp     mainLoopBody1
mainLoopBody2:
    mov     edx , [v]
    mov     eax , dword ptr [edx]
    mov     [y] , eax                       ; y = v[0]
    MX e, z, y, sum
    mov     eax , [n]
    dec     eax
    mov     edx , [v]
    mov     ebx , [edx+eax*4]               ; ebx = v[n-1]
    add     ebx , ecx
    mov     [edx+eax*4] , ebx               ; v[n-1] = v[n-1]+MX
    mov     [z] , ebx                       ; z = v[n-1]
    dec     [rounds]
    jne     mainLoop
    ret
XxteaEncode	endp


;функция чтения данных из файла
ReadXxteaData   PROC
    LOCAL   fileHandle : HANDLE
    mov     edx , OFFSET inputFileName
    invoke  OpenInputFile               ; откроем файл
    mov     fileHandle , eax            ; теперь в fileHandle лежит хэндлер для файла input
    .if eax == INVALID_HANDLE_VALUE     ; проверим нормальный ли хэндлер
        mov     error , 1               ; сообщим наверх, что была ошибка
        mov     edx , OFFSET fileOpenError
        call    WriteString             ; напечатаем ошибку на консоль
        ret                             ; и выйдем
    .endif
    mov     edx , OFFSET data
    mov     ecx , BUFFER_SIZE
    call    ReadFromFile                ; читаем из файла по-максимуму, но не больше BUFFER_SIZE
    .if eax == 0                        ; проверим сколько байт считалось
        mov     error , 1               ; если 0, сообщим наверх, что была ошибка
        mov     edx , offset dataError
        call    WriteString             ; напечатаем ее на консоль
        ret                             ; и выйдем
    .endif
    
    .if eax < 32
        mov     bytesRead , 32           ; размер ОТ должен быть не меньше 32 байт = 2 блока по 16 байт (подгоняем блок под размер ключа)
    .else
        mov     bytesRead , eax
        xor     edx , edx
        mov     ecx , 16
        div     ecx
        sub     ecx , edx               ; размер ОТ должен быть кратен 16
        .if ecx != 16
            add     bytesRead , ecx
        .endif
    .endif
    ret
ReadXxteaData   endp

;функция записи данных в файл
WriteXxteaResult    PROC
    LOCAL fileHandle : HANDLE

    INVOKE CreateFile, ADDR outputFileName, GENERIC_WRITE, DO_NOT_SHARE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0  ; создадим файл
    mov     fileHandle , eax            ; теперь в fileHandle лежит хэндлер для файла output
    .if eax == INVALID_HANDLE_VALUE     ; проверим нормальный ли хэндлер
        mov     edx , offset fileCreateError
        call    WriteString             ; напечатаем ошибку на консоль
        ret                             ; и выйдем
    .endif
    INVOKE WriteFile, fileHandle,ADDR x,16,ADDR bytesWritten,0    ; запишем результат в файл
    INVOKE CloseHandle, fileHandle                                          ; закроем хэндлер
    ret                                                                     ; и выйдем
WriteXxteaResult    endp


; Хэш-функция Давиэса-Мейера , на основе Xxtea
; H_i = f(x_i , H_i-1) = E_x_i(H_i-1) (+) H_i-1
XxteaHash       PROC
    
    mov     eax , [bytesRead]
    shr     eax , 4             ; переведем байты в блоки делением на 16 (1 блок = 16 байт)
    mov     blocksCount , eax   ; сохраним количество блоков ОТ

;Инициализируем H_0 как первый блок ОТ , ниже представлена операция копирования первых 16 байт из data в key
    xor     ecx , ecx
    lea     ebx , data
    lea     edx , key
H0Init:
    mov     eax , dword ptr [ebx + ecx*4]
    mov     [edx + ecx*4] , eax
    inc     ecx
    cmp     ecx , 4
    jne      H0Init
    mov     ecx , 1

; Цикл по блокам от 2 до последнего блока ОТ
hashLoop:
    push    ecx
;инициализируем x_i , операция копирования из data со смещением i*16
    shl     ecx , 4             ; умножим ecx на 16 (i*16)
    add     ecx , offset data   ; добавим смещение data от начала , получили адрес памяти, начиная от которого надо прочитать 16 байт
    xor     ebx , ebx
    lea     edx , x
XInit:
    mov     eax , dword ptr [ecx + ebx*4]   ; копируем из data
    mov     [edx + ebx*4] , eax             ; в x
    inc     ebx
    cmp     ebx , 4                         ; 4 раза (4*4байта = 16 байт)
    jne     XInit
;конец инициализации x_i
    invoke  XxteaEncode , ADDR x , 4   ; вызов функции шифрования , теперь в x находится E_x_i(H_i-1)
    ;будем ксорить E_x_i(H_i-1) с key (который на самом деле H_i-1) , таким образом получая Hi
    xor     ecx , ecx
    lea     ebx , x
    lea     edx , key

HiCopy:
    mov     eax , dword ptr [ebx + ecx*4]       ; получили x[i]
    xor     [edx + ecx*4] , eax                 ; xor   H_i-1[i] , x[i]
    inc     ecx
    cmp     ecx , 4
    jne      HiCopy

    pop     ecx                                 ; вернули счетчик по блокам
    inc     ecx                                 ; увеличили счетчик
    cmp     ecx , blocksCount
    jne     hashLoop                            ; если не достигли конца - обрабатываем следующий блок
    ret
XxteaHash           endp


main PROC
    call    ReadXxteaData       ; читаем входные данные
    .if error != 0              ; проверим прочитались или нет
        ret
    .endif
    call    XxteaHash           ; вызов хэш функции
    call    WriteXxteaResult    ; запишем результат в файл
    exit
main ENDP

END main    