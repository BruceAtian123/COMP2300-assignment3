.syntax unified
.global main

.include "libcomp2300/macros.S"

.type main, %function
main:
  @ Set up clock
  RCC_APB2ENR_set 0

  @ Set up GPIO port to receive the signal of the clock
  GPIOx_clock_enable B
  GPIOx_clock_enable D 
  GPIOx_clock_enable E 
  bl init

  @ Set up the NVIC interrupt
  NVIC_set ISER 6
  NVIC_set ISER 9

  @ Input pin PD0, PB3
  GPIO_configure_input_pin_it D, 0
  GPIO_configure_input_pin_it B, 3

  @ Output pin PE14, PE15
  GPIO_configure_output_pin E, 14
  GPIO_configure_output_pin E, 15

  @ Set up rising edge trigger
  EXTI_set_rising_edge_trigger 3

  @ Set up rising edge trigger and falling edge trigger
  EXTI_set_rising_edge_trigger 0
  EXTI_set_falling_edge_trigger 0
  
  @ Set up tim7 interrupt
  ldr r0, =0xe000e434     //start address
  mov r1, #88              //priority
  mov r2, #24              //index
  mov r3, #8               //width
  bl copy_bits

  @ Set up the wave
  ldr r0, =frequency1
  ldr r1, [r0]
  mov r0, r1
  mov r1, #0x7fff
  bl wave_change
  
  @ Initialize the time7 (1/ (80000000/ 10000*2000) = 0.25 s)
  ldr r0, =10000
  ldr r1, =2000
  bl tim7_init

@ play the audio
loop:
  ldr r4, =controll
  ldr r5, [r4]
  cmp r5, #1
  bne loop
  bl wave_play_next_sample
  b loop

.global EXTI0_IRQHandler
.type EXTI0_IRQHandler, %function
EXTI0_IRQHandler:
  push {lr, r4-r5}
  ldr r4, =controll
  @read in signal sent by PD0
  GPIOx_IDR_read D, #0
  cmp r0, #1
  bne continue
  mov r5, #1
  str r5, [r4]
  b end

continue:
  mov r5, #0
  str r5, [r4]

end:
  @clear interrup handler and pend register
  EXTI_PR_clear_pending 0
  pop {lr, r4-r5}
  bx lr
.size EXTI0_IRQHandler, .-EXTI0_IRQHandler

@Interrupt handler, change frequency when PE14 is toggled.
.global EXTI3_IRQHandler
.type EXTI3_IRQHandler, %function
EXTI3_IRQHandler:
  push {lr, r4-r11}
  ldr r6, =frequencyindex
  ldr r7, [r6]
  mov r9, r7
  lsl r9, r9, #2
  ldr r10, =frequency1
  ldr r8, [r10, r9]
  mov r0, r8
  ldr r1, =0x7fff
  @change the wave
  bl wave_change
  add r7, #1
  mov r11, #8
  @when the frequency table reaches the end, start from the beginning of the table again
  mod r4, r7, r11
  @store the new frequency index
  str r4, [r6]
  EXTI_PR_clear_pending 3
  pop {lr, r4-r11}
  bx lr
.size EXTI3_IRQHandler, .-EXTI3_IRQHandler

.data
frequency:
  .word 22000, 24693, 26163, 29366, 32963, 36999, 39200, 44000

frequency1:
  .word 22000, 26163, 24694, 29366, 26163, 32963, 29366, 36999, 44000, 39200, 36999, 32963, 29366, 26163, 24694, 22000

frequencyindex:
  .word 1

controll:
  .word 0