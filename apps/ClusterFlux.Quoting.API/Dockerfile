# Base image for runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

# SDK image for building
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# Copy and restore directly from current directory
COPY ClusterFlux.Quoting.API.csproj ./
RUN dotnet restore "./ClusterFlux.Quoting.API.csproj"

# Copy everything else and build
COPY . ./
RUN dotnet build "ClusterFlux.Quoting.API.csproj" -c $BUILD_CONFIGURATION -o /app/build

# Publish stage
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "ClusterFlux.Quoting.API.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# Final runtime image
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "ClusterFlux.Quoting.API.dll"]
