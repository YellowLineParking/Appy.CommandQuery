using System.Threading.Tasks;

namespace Appy.CommandQuery
{
    public interface ICommand<TResult, in TDataSource>
    {
        Task<TResult> Execute(TDataSource dataSource);
    }

    public interface ICommand<in TDataSource>
    {
        Task Execute(TDataSource dataSource);
    }
}