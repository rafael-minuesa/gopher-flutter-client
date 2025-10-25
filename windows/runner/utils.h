#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

std::vector<std::string> GetCommandLineArguments();

std::wstring Utf8ToWideString(const std::string& utf8_string);

#endif  // RUNNER_UTILS_H_
