# Appy.CommandQuery

![AppyWay logo](resources/appyway-100x100.png)

## What is Appy.CommandQuery?

Appy.CommandQuery is a package that allows you to separate data sources from the calling code by using messages as a mode of transport, rather than direct method calls.

## Packages

| Package | Latest Stable |
| --- | --- |
| [Appy.CommandQuery](https://www.nuget.org/packages/Appy.CommandQuery) | [![Nuget Package](https://img.shields.io/badge/nuget-2.1.0-blue.svg)](https://www.nuget.org/packages/Appy.CommandQuery) |


## Table of Contents

- [Testing](#testing)
- [Installing](#installing)
- [Usage](#usage)

### Testing
This project is tested with BrowserStack

### Installing

Install using the [Appy.CommandQuery NuGet package](https://www.nuget.org/packages/Appy.CommandQuery):

```
PM> Install-Package Appy.CommandQuery
```

### Usage


#### Creating a query

```
public class UserById : IQuery<IDbConnection, User>
{
  public string UserId {get; }
  public GetUserById(string userId) =>
    UserId = userId;

  public async Task<User> Get(IDbConnection connection)
  {
    using (var cmd = new SqlCommand("SELECT * FROM Users WHERE ID = @Id", connection))
    {
      cmd.Parameters.Add("@ID", SqlDbType.Int);
      cmd.Parameters["@ID"].Value = UserId;
    
      connection.Open();
      using (var reader = await cmd.ExecuteReaderAsync())
      {
        if (!reader.HasRows) return null;
        
        reader.Read();
        return new User
        {
          Id = UserId,
          Name = reader.GetString(reader.GetOrdinal("Name"))
          // ...
        }
      }
    }
  }
}
```

#### Executing a query
```
  var dataSource = new DataSource(() => new SqlConnection("connectionstring"));

  var user = await dataSource.Get(new UserById(myUserId));
```

### Decoupling datasource

In the above example, you're still required to instantiate the datasource and ensure you provide the correct callback in the constructor of the data source.
The goal is to inject the data source, so your calling code can be independent.

Here's an example using the Ninject DI container:

Composition root
```
  Kernel.Bind<IDataSource>
        .ToConstant(ctx => new DataSource(type => Kernel.GetInstance(type)));
```

Client

```
public class SomeClient
{
  IDataSource _dataSource;
  public SomeClient(IDataSource dataSource) => 
    _dataSource = dataSource;

  public async Task SomeMethod()
  {
    var myUserId = "123";
    var user = await dataSource.Get(new UserById(myUserId));
    // ...
  }
}
```

This effectively decouples the client class from the underlying datasource, because all the details will be handled in the composition root.
Even if you have multiple data sources (SQL database, network calls, azure table storage, ...), you only need a reference to an appropriately configured `IDataSource` to handle all underlying setup:

`Note: naming of queries is for clarity. I'd advise against putting the type of the datasource in the class name as that would leak details to the client`
```
class UserFromSql : IQuery<IDbConnection, User>
{
  public Task<User> Get(IDbConnection connection)
  {
    // Use IDbConnection to retrieve user
  }

}
```
```
class ProductFromApi : IQuery<HttpClient, Product>
{
  public Task<Product> Get(HttpClient client)
  {
    // Use HttpClient to get product
  }
}
```
```
class BlobFromAzure : IQuery<CloudBlobContainer, Stream>
{
  public Task<Strean> Get(CloudBlobContainer blobContainer)
  {
    // Use CloudBlobContainer to get stream
  }
}
```

Now, you can use all three queries to connect to different data sources without being dependent on the underlying data sources:


```
public class SomeClient
{
  IDataSource _dataSource;
  public SomeClient(IDataSource dataSource) => 
    _dataSource = dataSource;

  public async Task SomeMethod()
  {
    var user = await dataSource.Get(new UserFromSql());
    var product = await dataSource.Get(new ProductFromApi());
    var blob = await dataSource.Get(new BlobFromAzure());
    // ...
  }
}
```

### Commands

Commands work in the same way as queries, except that they don't have a return type:

```
public class UpdateUserName : IQuery<IDbConnection, User>
{
  public string UserId {get; }
  public string Name {get; }
  
  public UpdateUserName(string userId, string name)
  {
    UserId = userId;
    Name = name;
  }

  public async Task Execute(IDbConnection connection)
  {
    using (var cmd = new SqlCommand("UPDATE Users SET Name = @Name WHERE ID = @Id", connection))
    {
      cmd.Parameters.Add("@ID", SqlDbType.Int);
      cmd.Parameters["@ID"].Value = UserId;

      cmd.Parameters.Add("@Name", SqlDbType.NVarChar);
      cmd.Parameters["@Name"].Value = Name;
    
      connection.Open();
      await cmd.ExecuteNonQueryAsync();
    }
  }
}
```

```
public class SomeClient
{
  IDataSource _dataSource;
  public SomeClient(IDataSource dataSource) => 
    _dataSource = dataSource;

  public async Task SomeMethod()
  {
    await dataSource.Execute(new UpdateUserName("123", "new name"));
    // ...
  }
}
```

NOTE: there's also an `ICommand` interface available which does have a return type. It is functionally equivalent to the `IQuery` interface, but changes the semantics. This can be used in cases where you want to return the result of executing a command (eg: Inserting a user and returning the ID).

### Testing

Rather than having to mock a myriad of interfaces to swap out all external dependencies you can mock just the `IDataSource` and verify that the correct queries have been executed.

Example using Moq, verifying whether all queries were correctly executed:

``` 
var dataSourceMock = new Mock<IDataSource>();

dataSourceMock.Verify(dataSource => dataSource.Execute(It.IsAny<UpdateUsername>()));
dataSourceMock.Verify(dataSource => dataSource.Get(It.Is<UserById>(q => q.UserId == "123")));
dataSourceMock.Verify(dataSource => dataSource.Execute(It.IsAny<ProductFromApi>()));
dataSourceMock.Verify(dataSource => dataSource.Execute(It.IsAny<BlobFromAzure>()));
```

Or, you can also setup the mock to return expected results:

```
dataSourceMock.Setup(dataSource => dataSource.Execute(It.IsAny<ProductFromApi>()))
              .Returns(Task.FromResult(new Product()));
```


## Contribute
It would be awesome if you would like to contribute code or help with bugs. Just follow the guidelines [CONTRIBUTING](https://github.com/YellowLineParking/Appy.CommandQuery/blob/master/CONTRIBUTING.md)
