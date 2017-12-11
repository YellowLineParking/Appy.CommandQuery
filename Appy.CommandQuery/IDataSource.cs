using System.Threading.Tasks;

namespace Appy.CommandQuery
{
    public interface IDataSource
    {
        Task<TReturnType> Get<TReturnType, TDataSource>(IQuery<TReturnType, TDataSource> query);
        Task<TReturnType> Execute<TReturnType, TDataSource>(ICommand<TReturnType, TDataSource> command);
        Task Execute<TDataSource>(ICommand<TDataSource> command);
    }
}