# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["VisitorCounter.csproj", "."]
RUN dotnet restore "./VisitorCounter.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "VisitorCounter.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "VisitorCounter.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .
USER $APP_UID
ENTRYPOINT ["dotnet", "VisitorCounter.dll"]

ENV ASPNETCORE_URLS=http://+:5000
EXPOSE 5000
