@echo off
:: 切换代码页为 UTF-8
chcp 65001 >nul
echo ========================================
echo   开始打包 Flutter Windows 程序...
echo ========================================


:: 2. 执行打包命令
echo [2/3] 正在执行打包编译 (Release 模式)...
call flutter build windows --release

:: 检查上一步是否成功
if %errorlevel% neq 0 (
    echo.
    echo [错误] 打包过程出错，请检查控制台输出。
    pause
    exit /b %errorlevel%
)

:: 3. 定位并打开目录
echo [3/3] 打包完成！正在打开输出目录...

:: 设置构建结果的路径
set BUILD_PATH=%cd%\build\windows\x64\runner\Release

:: 打开该目录
start "" "%BUILD_PATH%"

echo.
echo ========================================
echo   打包成功！EXE 文件位于打开的窗口中。
echo ========================================
pause