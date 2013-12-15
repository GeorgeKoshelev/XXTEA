.386 

option casemap:none

;����� ������ ����������, ��� �������������� � �������� ��������
INCLUDE Irvine32.inc


;����: e,z,y,sum
;�����: ecx =  (((z>>5)^(y<<2))+((y>>3)^(z<<4)))^((sum^y)+(k[(p&3)^e]^z))

MX macro e, z, y, sum
    mov     ecx , [z]
    shr     ecx , 5         ; z>>5
    mov     edx , [y]
    shl     edx , 2         ; y<<2
    xor     ecx , edx       ; ��������� (z>>5)^(y<<2)
    mov     eax , [y]
    shr     eax , 3         ; y>>3
    mov     edx , [z]
    shl     edx , 4         ; z<<4
    xor     eax , edx       ; ��������� (y>>3)^(z<<4)
    add     ecx , eax       ; ��������� ((z>>5)^(y<<2))+((y>>3)^(z<<4))
    mov     eax , [sum]
    xor     eax , [y]       ; ��������� (sum^y)
    mov     edx , [p]
    and     edx , 3         ; ��������� (p&3)
    xor     edx , [e]       ; (p&3)^e
    mov     esi , offset key
    mov     edx , [esi+edx*4] ; edx = k[(p&3)^e]
    xor     edx , [z]         ; k[(p&3)^e]^z
    add     eax , edx         ; (sum^y)+(k[(p&3)^e]^z)
    xor     ecx , eax         ; ((z>>5)^(y<<2))+((y>>3)^(z<<4)))^((sum^y)+(k[(p&3)^e]^z)) 
endm

.const

BUFFER_SIZE     equ     65535   ; ��������� ������������ ������ ������� ������ 65535 �������
DELTA           equ     -1640531527 ; DELTA 

.data
key             BYTE    16          DUP(0)  ;   ������ �����. ����� ����� = 16 ���� = 128 ���
data            BYTE    BUFFER_SIZE DUP(0)  ;   ������ ������� ������

inputFileName   BYTE    "input",0   ; ��������� �������� ����� � �������� �������
keyFileName     BYTE    "key",0     ; ��� ����� � ������
outputFileName  BYTE    "output",0  ; �������� ����� ��� ������ ����������


error           BYTE        0       ; ��������� ��� ����������� �� �������� �� ����� ������ � �������� ��������. ���� error != 0 ��������� ������
bytesRead       DWORD       0       ; ���������� ����������� ����
bytesWritten    DWORD       16      ; ���������� ���������� ����

;���� ����������� ��������� ������
fileCreateError     BYTE    "Error: failed to create file",0dh,0ah,0
fileOpenError       BYTE    "Error: failed to open file",0dh,0ah,0
BadKeyError         BYTE    "Error: key length is wrong",0dh,0ah,0
dataError           BYTE    "Error: data file is empty",0dh,0ah,0

.code

;�������, ����������� �������� �������������
;������� ��������� - pointer - ��������� �� ������ � ������������ (��) , n - ���������� ������ ��
XxteaDecode PROC uses ebx v: DWORD, n:DWORD
    LOCAL   y : DWORD
    LOCAL   z : DWORD
    LOCAL   sum : DWORD
    LOCAL   p : DWORD
    LOCAL   rounds: DWORD
    LOCAL   e : DWORD
    ;���������� ������� ������������ �� ������� 6+52/n
    .if [n] > 52
        mov [rounds] , 6        ; ���� n>52 ����� (52/n < 1) => ����� ��������� ��� ���������
    .else
        mov     ecx , 6
        mov     eax , 52
        mov     ebx , [n]
        and     ebx , 0ffh
        div     bl
        add     cl , al
        xor     eax , eax
        mov     al , cl
        mov     rounds , eax    ; ��������� ���������� �������
    .endif
    mov     ecx , [rounds]
    imul    ecx , DELTA
    mov     [sum] , ecx         ; sum = rounds*DELTA
    mov     edx , [v]
    mov     eax , [edx]
    mov     [y] , eax           ; y = v[0]
mainLoop:
    mov     ecx , [sum]
    shr     ecx , 2
    and     ecx , 3
    mov     [e] , ecx           ; e = (sum >> 2) & 3
    mov     edx , [n]
    dec     edx
    mov     [p] , edx           ; p=n-1
    jmp     short   innerLoopBody
mainLoopBody1:                         ;���������� ����
    mov     eax , [p]
    dec     eax
    mov     [p] , eax                   ; ��������� p
innerLoopBody:                          ; ���� ����������� �����
    cmp     [p] , 0                     ; ���� p!=0 ����� ��������� z = v[p-1], y = v[p] -= MX, � ��������� ������ ������������ � ������� ����
    jbe     short   mainLoopBody2
    mov     ecx , [p]
    dec     ecx                         ; p-1
    mov     edx , [v]
    mov     eax , [edx+ecx*4]           ; v[p-1]
    mov     [z] , eax                   ; z = v[p-1]
    MX e, z, y, sum                     ; �������� MX , ������� � ecx ���������
    mov     eax , [p]
    mov     edx , [v]
    mov     ebx , dword ptr [edx+eax*4] 
    sub     ebx , ecx                   ; v[p]-MX
    mov     DWORD PTR [edx+eax*4], ebx  ; v[p] = v[p] - MX
    mov     [y] , ebx                   ; y = v[p] - MX
    jmp     short   mainLoopBody1
mainLoopBody2:
    mov     edx , [n]
    dec     edx                         ; n-1
    mov     eax , [v]
    mov     ecx , dword ptr [eax+edx*4]
    mov     [z] , ecx                   ; z = v[n-1]
    MX e, z, y, sum                     ; �������� MX , ������� � ecx ���������
    mov     edx , [v]
    mov     eax , dword ptr [edx]
    sub     eax , ecx                   ; v[0]-MX
    mov     dword ptr [edx], eax        ; v[0] = v[0]-MX
    mov     [y] , eax                   ; y = v[0]
    mov     ecx , [sum]
    sub     ecx , DELTA
    mov     [sum] , ecx                 ; sum -= DELTA
    jne mainLoop

	ret
XxteaDecode	endp

;������� ������ ����� �� ����� key
ReadXxteaKey PROC
    LOCAL   fileHandle : HANDLE
    mov     edx , OFFSET keyFileName
    invoke  OpenInputFile               ; ������� ����
    mov     fileHandle , eax            ; ������ � fileHandle ����� ������� ��� ����� key
    .if eax == INVALID_HANDLE_VALUE     ; �������� ���������� �� �������
        mov     error , 1               ; ������� ������, ��� ���� ������
        mov     edx , OFFSET fileOpenError
        call    WriteString             ; ���������� ������ �� �������
        ret                             ; � ������
    .endif
    mov     edx , OFFSET key
    mov     ecx , 16                    ; �������, ��� ���� ������ 16 ����
    call    ReadFromFile                ; � ������� �������
    .if eax !=  16                      ; �������� ��������� �� 16 ����
        mov     error , 1               ; ���� ��� - ������ ������, ��� ��������� ������
        mov     edx , offset BadKeyError
        call    WriteString             ; ���������� ������ � �������
    .endif
    mov     eax , fileHandle
    call    CloseFile                   ;����� ������� ������� � ������
    ret
ReadXxteaKey endp

;������� ������ ������ �� �����
ReadXxteaData   PROC
    LOCAL   fileHandle : HANDLE
    mov     edx , OFFSET inputFileName
    invoke  OpenInputFile               ; ������� ����
    mov     fileHandle , eax            ; ������ � fileHandle ����� ������� ��� ����� input
    .if eax == INVALID_HANDLE_VALUE     ; �������� ���������� �� �������
        mov     error , 1               ; ������� ������, ��� ���� ������
        mov     edx , OFFSET fileOpenError
        call    WriteString             ; ���������� ������ �� �������
        ret                             ; � ������
    .endif
    mov     edx , OFFSET data
    mov     ecx , BUFFER_SIZE
    call    ReadFromFile                ; ������ �� ����� ��-���������, �� �� ������ BUFFER_SIZE
    .if eax == 0                        ; �������� ������� ���� ���������
        mov     error , 1               ; ���� 0, ������� ������, ��� ���� ������
        mov     edx , offset dataError
        call    WriteString             ; ���������� �� �� �������
        ret                             ; � ������
    .endif
    
    .if eax < 8
        mov     bytesRead , 8           ; ������ �� ������ ���� �� ������ 64 ���
    .else
        mov     bytesRead , eax
        xor     edx , edx
        mov     ecx , 4
        div     ecx
        sub     ecx , edx               ; ������ �� ������ ���� ������ 4
        .if ecx != 4
            add     bytesRead , ecx
        .endif
    .endif
    ret
ReadXxteaData   endp

;������� ������ ������ � ����
WriteXxteaResult    PROC
    LOCAL fileHandle : HANDLE

    INVOKE CreateFile, ADDR outputFileName, GENERIC_WRITE, DO_NOT_SHARE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0  ; �������� ����
    mov     fileHandle , eax            ; ������ � fileHandle ����� ������� ��� ����� output
    .if eax == INVALID_HANDLE_VALUE     ; �������� ���������� �� �������
        mov     edx , offset fileCreateError
        call    WriteString             ; ���������� ������ �� �������
        ret                             ; � ������
    .endif
    INVOKE WriteFile, fileHandle,ADDR data,bytesRead,ADDR bytesWritten,0    ; ������� ��������� � ����
    INVOKE CloseHandle, fileHandle                                          ; ������� �������
    ret                                                                     ; � ������
WriteXxteaResult    endp

main PROC
    call    ReadXxteaKey    ; ��������� ����
    .if error != 0          ; �������� ���������� ��� ���
        ret
    .endif
    call    ReadXxteaData   ; ������ ������� ������
    .if error != 0          ; �������� ����������� ��� ���
        ret
    .endif
    mov     eax , [bytesRead]
    shr     eax , 2         ; ��������� ����� � ����� �������� �� 4
    invoke  XxteaDecode , ADDR data , eax   ; ����� ������� �������������
    call    WriteXxteaResult    ; ������� ��������� � ����
    exit
main ENDP

END main